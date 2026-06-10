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

/** Wire contract for the chat turn body. Canonical casing is camelCase —
 * the iOS encoder must NOT snake_case keys. Exported for contract tests. */
export const ChatBody = z
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

  const threadId = c.req.param("id").toLowerCase();
  const body = ChatBody.safeParse(await c.req.json().catch(() => ({})));
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
    signal: c.req.raw.signal,
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
  signal?: AbortSignal;
}

export interface PendingToolCall {
  id: string;
  name: string;
  arguments: string;
}

/** Fold a streamed tool-call delta into the per-round accumulator. */
export function accumulateToolCallDelta(
  map: Map<number, PendingToolCall>,
  delta: { index: number; id?: string; name?: string; argumentsDelta?: string }
): void {
  const entry = map.get(delta.index) ?? { id: "", name: "", arguments: "" };
  if (delta.id) entry.id = delta.id;
  if (delta.name) entry.name = delta.name;
  if (delta.argumentsDelta) entry.arguments += delta.argumentsDelta;
  map.set(delta.index, entry);
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
    signal,
  } = args;

  yield { type: "thread_id", data: { thread_id: threadId } };

  // Each turn may bounce between the model emitting tool calls and us
  // resolving them. Cap iterations so a runaway loop can't spin forever.
  const MAX_TOOL_ROUNDS = 6;
  let assistantText = "";
  const emittedArtifacts: ArtifactEmission[] = [];
  const turnTranscript: ChatMessage[] = [...conversation];

  try {
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    if (signal?.aborted) return;

    let roundText = "";
    const pending = new Map<number, PendingToolCall>();
    const chunks = llm.chat({
      stream: true,
      messages: turnTranscript,
      tools,
      temperature: 0.4,
      maxTokens: 4096,
      signal,
    });
    for await (const chunk of chunks) {
      if (chunk.delta) {
        roundText += chunk.delta;
        assistantText += chunk.delta;
        yield { type: "text_delta", data: { chunk: chunk.delta } };
      }
      for (const tc of chunk.toolCallDeltas ?? []) {
        accumulateToolCallDelta(pending, tc);
      }
    }

    const calls = [...pending.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([, c]) => c)
      .filter((c) => c.id && c.name);
    if (calls.length === 0) {
      break;
    }

    // Push the assistant's tool-call message — with `tool_calls` — into the
    // transcript so the subsequent `tool` replies reference a real request.
    turnTranscript.push({
      role: "assistant",
      content: roundText,
      tool_calls: calls.map((call) => ({
        id: call.id,
        type: "function" as const,
        function: { name: call.name, arguments: call.arguments || "{}" },
      })),
    });

    for (const pendingCall of calls) {
      const call = {
        id: pendingCall.id,
        function: { name: pendingCall.name, arguments: pendingCall.arguments || "{}" },
      };
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
  } catch (err) {
    if (signal?.aborted) return;
    // Never leak provider/internal error text to the client.
    console.error("[chat-stream] turn failed", err);
    yield {
      type: "error",
      data: { message: "The coach hit a problem generating a reply. Please try again." },
    };
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

export function friendlyToolLabel(name: string): string {
  switch (name) {
    case "getProfile": return "Reading your profile";
    case "getDayLog": return "Reading today's log";
    case "getRange": return "Pulling recent history";
    case "getHealthSnapshot": return "Reading today's vitals";
    case "getDrinkLog": return "Reading today's drinks";
    case "getActivityStatus": return "Checking your status";
    case "getCycleData": return "Reading cycle data";
    case "getCycleInsight": return "Analyzing your cycle";
    case "addFoodEntry": return "Logging the meal";
    case "correctFoodEntry": return "Updating the meal";
    case "addDrink": return "Logging the drink";
    case "setActivityStatus": return "Updating your status";
    case "addCycleEntry": return "Logging cycle data";
    case "addWeightEntry": return "Saving your weight";
    case "completeWorkout": return "Saving the workout";
    case "searchMemories": return "Searching memories";
    case "addMemory": return "Saving a memory";
    case "removeMemory": return "Removing a memory";
    case "scheduleCheckIn": return "Scheduling a check-in";
    case "analyzeImpact": return "Analyzing impact";
    case "analyzeImpactByTag": return "Analyzing habit impact";
    case "predict": return "Forecasting metrics";
    case "computeBiologicalAge": return "Estimating biological age";
    case "classifyJournalEntry": return "Tagging the journal entry";
    case "proposeWorkout": return "Designing a workout";
    case "proposePlan": return "Drafting a plan";
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
