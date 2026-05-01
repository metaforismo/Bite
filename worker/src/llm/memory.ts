/**
 * Post-turn memory extractor.
 *
 * Runs after every assistant message. Calls a cheap Haiku pass that proposes
 * 0..3 canonical user facts (Goals / Nutrition / Exercise Preferences /
 * Barriers / Dislikes / Recovery / Skincare / Weight). Each is then deduped
 * against existing memories — first by exact text, then by Vectorize cosine
 * similarity > 0.92 — and inserted only if novel.
 */
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { memories } from "../db/schema";
import { LLMRouter } from "./router";
import type { ChatMessage } from "./router";
import type { Env } from "../types";
import type { DB } from "../tools/types";
import { queryMemories, upsertMemoryEmbedding } from "./embed";

const ProposedSchema = z.object({
  facts: z
    .array(
      z.object({
        category: z.string(),
        text: z.string().min(2).max(500),
      })
    )
    .max(5),
});

const SYSTEM = `You extract canonical user facts worth remembering across conversations.

Allowed categories: Goals, Nutrition, Exercise Preferences, Barriers, Dislikes, Recovery, Skincare, Weight, Equipment.

Rules:
- Return JSON only — no prose.
- 0 facts is fine. Prefer fewer + higher quality.
- Skip ephemera: today's mood, one-off meals, anything the user might change tomorrow.
- Each fact must be a single sentence in the third person ("User trains 3x/week mornings.").
- Skip facts that are obviously already common knowledge or already implied by an earlier system message.

Return shape:
{ "facts": [ { "category": "...", "text": "..." } ] }`;

export async function extractAndStoreMemories(args: {
  uid: string;
  llm: LLMRouter;
  env: Env;
  db: DB;
  recentTurn: ChatMessage[];
  existingMemorySnippets: string[];
}): Promise<{ inserted: number }> {
  const { uid, llm, env, db, recentTurn, existingMemorySnippets } = args;

  const proposedRaw = await llm.chat({
    cheap: true,
    temperature: 0,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          existingMemorySnippets.length > 0
            ? `Existing memories (do not duplicate):\n${existingMemorySnippets
                .map((s) => `- ${s}`)
                .join("\n")}\n\n` +
              "Latest exchange:\n" +
              recentTurn.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join("\n")
            : recentTurn.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join("\n"),
      },
    ],
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(extractFirstJsonObject(proposedRaw.content));
  } catch {
    return { inserted: 0 };
  }
  const validated = ProposedSchema.safeParse(parsed);
  if (!validated.success) return { inserted: 0 };
  if (validated.data.facts.length === 0) return { inserted: 0 };

  // Pull existing memory rows for dedupe.
  const existing = await db
    .select()
    .from(memories)
    .where(eq(memories.firebaseUid, uid));
  const existingTexts = new Set(existing.map((m) => m.text.trim().toLowerCase()));

  let inserted = 0;
  for (const fact of validated.data.facts) {
    const lower = fact.text.trim().toLowerCase();
    if (existingTexts.has(lower)) continue;

    // Semantic dedupe via Vectorize (best-effort — if the index isn't bound
    // or the lookup fails we fall back to exact-text dedupe only).
    let semanticDuplicate = false;
    try {
      const matches = await queryMemories(uid, fact.text, 3, env);
      semanticDuplicate = matches.some((m) => m.score > 0.92);
    } catch (err) {
      console.warn("[memory] vector dedupe failed", err);
    }
    if (semanticDuplicate) continue;

    const id = crypto.randomUUID();
    const now = Date.now();
    await db.insert(memories).values({
      id,
      firebaseUid: uid,
      category: fact.category,
      text: fact.text,
      createdAt: now,
      updatedAt: now,
    });
    existingTexts.add(lower);
    inserted += 1;

    // Best-effort embedding upsert for future dedupe.
    try {
      await upsertMemoryEmbedding(uid, id, fact.text, fact.category, env);
    } catch (err) {
      console.warn("[memory] vector upsert failed", err);
    }
  }
  return { inserted };
}

function extractFirstJsonObject(content: string): string {
  const fence = content.match(/```json\s*([\s\S]*?)```/);
  if (fence) return fence[1];
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  if (start >= 0 && end > start) return content.slice(start, end + 1);
  return content;
}
