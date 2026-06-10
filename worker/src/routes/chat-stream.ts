/**
 * Streaming chat-turn implementation.
 *
 *   POST /v1/chat/threads/:id/messages
 *
 * Body:
 *   { text: string, healthSnapshot?: HealthSnapshot, attachments?: [{fileId, kind}] }
 *
 * Returns an SSE stream of typed events:
 *   thread_id     — { thread_id }
 *   thinking_step — { id, label, status }
 *   tool_call     — { tool, args }
 *   tool_result   — { tool, result }
 *   text_delta    — { chunk }
 *   artifact      — { id, type, payload, version }
 *   error         — { message }
 *   done          — {}
 *
 * Behaviour:
 *   - Validates ownership of the thread,
 *   - Persists the user message immediately,
 *   - Pulls the user's existing memories as a preamble,
 *   - Runs an OpenRouter chat completion with the full tool registry,
 *   - Dispatches every tool call locally, feeding results back to the model,
 *   - Streams text deltas and artifact emissions to the client,
 *   - After the assistant message completes, runs the cheap memory-extraction
 *     pass and persists the final message.
 */
import { Hono } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { and, desc, eq } from "drizzle-orm";
import { z } from "zod";
import { activityStatus } from "../db/schema";
import {
  artifacts as artifactsTable,
  memories,
  messages,
  threads,
  toolCalls,
} from "../db/schema";
import type { AppBindings } from "../types";
import { sseResponse, type SSEEvent } from "../sse";
import { LLMRouter, type ChatMessage } from "../llm/router";
import { BITE_SYSTEM_PROMPT, activityStatusPreamble, memoriesPreamble } from "../llm/system-prompts";
import { buildRegistry } from "../tools/registry";
import type { ArtifactEmission, HealthSnapshot, ThinkingStepEmission } from "../tools/types";
import { extractAndStoreMemories } from "../llm/memory";

const router = new Hono<AppBindings>();

const Body = z
  .object({
    text: z.string().min(1).max(20_000),
    healthSnapshot: z.record(z.unknown()).optional(),
    attachments: z
      .array(
        z.object({
          fileId: z.string().uuid(),
          kind: z.string(),
        })
      )
      .optional(),
  })
  .strict();

router.post("/chat/threads/:id/messages", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);

  const threadId = c.req.param("id");
  const body = Body.safeParse(await c.req.json().catch(() => ({})));
  if (!body.success) {
    return c.json({ error: "invalid_body", issues: body.error.issues }, 400);
  }

  const db = drizzle(c.env.DB);

  // Ownership check
  const threadRow = (
    await db
      .select()
      .from(threads)
      .where(and(eq(threads.id, threadId), eq(threads.firebaseUid, uid)))
      .limit(1)
  )[0];
  if (!threadRow) return c.json({ error: "not_found" }, 404);

  const userMessageId = crypto.randomUUID();
  const userTs = Date.now();
  await db.insert(messages).values({
    id: userMessageId,
    threadId,
    firebaseUid: uid,
    role: "user",
    text: body.data.text,
    createdAt: userTs,
  });

  const llm = new LLMRouter(c.env);
  const registry = buildRegistry();

  // Recent context: last ~20 messages for tight token budget.
  const priorRows = await db
    .select()
    .from(messages)
    .where(eq(messages.threadId, threadId))
    .orderBy(desc(messages.createdAt))
    .limit(20);
  const prior: ChatMessage[] = priorRows
    .slice()
    .reverse()
    .map((m) => ({ role: m.role as ChatMessage["role"], content: m.text }));

  // Memory preamble.
  const memoryRows = await db
    .select()
    .from(memories)
    .where(eq(memories.firebaseUid, uid))
    .orderBy(desc(memories.updatedAt))
    .limit(40);
  const memorySnippets = memoryRows.map((m) => `[${m.category}] ${m.text}`);

  // V2 — read latest activity status so the system prompt can acknowledge
  // sick / injured / on-break states without a tool round-trip.
  const statusRows = await db
    .select()
    .from(activityStatus)
    .where(eq(activityStatus.firebaseUid, uid))
    .orderBy(desc(activityStatus.startedAt))
    .limit(1);
  const statusPreamble = statusRows[0]
    ? activityStatusPreamble({
        kind: statusRows[0].kind as "active" | "sick" | "injured" | "on_break",
        daysActive: Math.max(
          0,
          Math.floor((Date.now() - statusRows[0].startedAt) / 86400000)
        ),
        note: statusRows[0].note,
      })
    : "";

  const systemContent = [
    BITE_SYSTEM_PROMPT,
    statusPreamble,
    memoriesPreamble(memorySnippets),
  ]
    .filter((s) => s && s.length > 0)
    .join("\n\n");

  const conversation: ChatMessage[] = [
    { role: "system", content: systemContent },
    ...prior,
  ];

  const tools = registry.toOpenAITools();

  const stream = run({
    db,
    env: c.env,
    llm,
    registry,
    uid,
    threadId,
    userMessageId,
    conversation,
    tools,
    healthSnapshot: body.data.healthSnapshot as HealthSnapshot | undefined,
    memorySnippets,
  });
  return sseResponse(stream);
});

interface RunArgs {
  db: ReturnType<typeof drizzle>;
  env: AppBindings["Bindings"];
  llm: LLMRouter;
  registry: ReturnType<typeof buildRegistry>;
  uid: string;
  threadId: string;
  userMessageId: string;
  conversation: ChatMessage[];
  tools: ReturnType<ReturnType<typeof buildRegistry>["toOpenAITools"]>;
  healthSnapshot?: HealthSnapshot;
  memorySnippets: string[];
}

async function* run(args: RunArgs): AsyncGenerator<SSEEvent, void, unknown> {
  const {
    db,
    env,
    llm,
    registry,
    uid,
    threadId,
    userMessageId: _userMessageId,
    conversation,
    tools,
    healthSnapshot,
    memorySnippets,
  } = args;

  yield { type: "thread_id", data: { thread_id: threadId } };

  // Each turn may bounce between the model emitting tool calls and us
  // resolving them. Cap iterations so a runaway loop can't spin forever.
  const MAX_TOOL_ROUNDS = 6;
  let assistantText = "";
  const emittedArtifacts: ArtifactEmission[] = [];
  const turnTranscript: ChatMessage[] = [...conversation];

  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const result = await llm.chat({
      stream: false,
      messages: turnTranscript,
      tools,
      temperature: 0.4,
    });

    // Emit any text the model produced before the tool call.
    if (result.content && result.content.length > 0) {
      assistantText += result.content;
      // Stream as a single delta — non-streaming completions deliver content
      // in one piece; the iOS UI handles arbitrary chunk sizes.
      yield { type: "text_delta", data: { chunk: result.content } };
    }

    if (!result.toolCalls || result.toolCalls.length === 0) {
      break;
    }

    // Push the assistant's tool-call message into the transcript so the model
    // sees its own request in the next round.
    turnTranscript.push({
      role: "assistant",
      content: result.content || "",
    });

    for (const call of result.toolCalls) {
      const thinkId = `tool.${call.id}`;
      const stepEmission: ThinkingStepEmission = {
        id: thinkId,
        label: friendlyToolLabel(call.function.name),
        status: "running",
      };
      yield { type: "thinking_step", data: stepEmission };

      yield {
        type: "tool_call",
        data: { tool: call.function.name, args: safeJSON(call.function.arguments) },
      };

      const dispatchEmissions: { artifact: ArtifactEmission[]; thinking: ThinkingStepEmission[] } = {
        artifact: [],
        thinking: [],
      };
      const dispatch = await registry.dispatch(call.function.name, call.function.arguments, {
        uid,
        threadId,
        db,
        env,
        llm,
        healthSnapshot,
        emit: {
          artifact: (a) => dispatchEmissions.artifact.push(a),
          thinking: (s) => dispatchEmissions.thinking.push(s),
        },
      });

      // Replay any thinking + artifact emissions the tool produced.
      for (const t of dispatchEmissions.thinking) {
        yield { type: "thinking_step", data: t };
      }
      for (const a of dispatchEmissions.artifact) {
        emittedArtifacts.push(a);
        yield { type: "artifact", data: a };
      }

      yield {
        type: "thinking_step",
        data: { ...stepEmission, status: dispatch.ok ? "done" : "failed" },
      };

      yield {
        type: "tool_result",
        data: { tool: call.function.name, result: dispatch.output },
      };

      // Audit log.
      await db.insert(toolCalls).values({
        id: crypto.randomUUID(),
        firebaseUid: uid,
        threadId,
        tool: call.function.name,
        argsJSON: typeof call.function.arguments === "string"
          ? call.function.arguments
          : JSON.stringify(call.function.arguments ?? {}),
        resultJSON: JSON.stringify(dispatch.output ?? null),
        latencyMs: dispatch.latencyMs,
        createdAt: Date.now(),
      });

      // Feed the tool result back to the model.
      turnTranscript.push({
        role: "tool",
        name: call.function.name,
        tool_call_id: call.id,
        content: typeof dispatch.output === "string" ? dispatch.output : JSON.stringify(dispatch.output),
      });
    }
  }

  // Persist final assistant message + any artifact rows.
  const assistantId = crypto.randomUUID();
  const now = Date.now();
  if (assistantText.length > 0) {
    await db.insert(messages).values({
      id: assistantId,
      threadId,
      firebaseUid: uid,
      role: "assistant",
      text: assistantText,
      createdAt: now,
    });
  }
  for (const a of emittedArtifacts) {
    try {
      await db.insert(artifactsTable).values({
        id: a.id,
        messageId: assistantId,
        firebaseUid: uid,
        type: a.type,
        payloadJSON: JSON.stringify(a.payload),
        version: a.version,
        createdAt: now,
      });
    } catch {
      // Conflict on (id) means we're updating an existing artifact (versioned edit).
      await db
        .update(artifactsTable)
        .set({
          payloadJSON: JSON.stringify(a.payload),
          version: a.version,
        })
        .where(and(eq(artifactsTable.id, a.id), eq(artifactsTable.firebaseUid, uid)));
    }
  }

  await db
    .update(threads)
    .set({ lastMessageAt: now })
    .where(and(eq(threads.id, threadId), eq(threads.firebaseUid, uid)));

  // Memory extraction (best-effort, swallow errors so the user still gets `done`).
  try {
    const lastUser = conversation[conversation.length - 1];
    const turnPair: ChatMessage[] = [];
    if (lastUser) turnPair.push(lastUser);
    if (assistantText.length > 0) {
      turnPair.push({ role: "assistant", content: assistantText });
    }
    if (turnPair.length > 0) {
      await extractAndStoreMemories({
        uid,
        llm,
        env,
        db,
        recentTurn: turnPair,
        existingMemorySnippets: memorySnippets,
      });
    }
  } catch (err) {
    console.warn("[chat-stream] memory extraction failed", err);
  }
}

function friendlyToolLabel(name: string): string {
  switch (name) {
    case "get_profile": return "Reading your profile";
    case "get_day_log": return "Reading today's log";
    case "get_range": return "Pulling recent history";
    case "get_health_snapshot": return "Reading today's vitals";
    case "add_food_entry": return "Logging the meal";
    case "correct_food_entry": return "Updating the meal";
    case "search_memories": return "Searching memories";
    case "add_memory": return "Saving a memory";
    case "remove_memory": return "Removing a memory";
    case "schedule_check_in": return "Scheduling a check-in";
    case "analyze_impact": return "Analyzing impact";
    case "predict": return "Forecasting metrics";
    case "propose_workout": return "Designing a workout";
    case "propose_plan": return "Drafting a plan";
    case "add_lab_report": return "Reading the lab document";
    case "get_biomarkers": return "Loading biomarkers";
    case "research_science": return "Searching scientific sources";
    default: return `Running ${name}`;
  }
}

function safeJSON(value: string | unknown): unknown {
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return value; }
}

export default router;
