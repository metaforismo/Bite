import { z } from "zod";
import { journalTags } from "../db/schema";
import { defineTool } from "./types";

const TAG_CATALOG = [
  // lifestyle
  { tag: "Late meal", category: "lifestyle" },
  { tag: "Alcohol", category: "lifestyle" },
  { tag: "Caffeine after 4pm", category: "lifestyle" },
  { tag: "Heavy carb", category: "lifestyle" },
  { tag: "High protein", category: "lifestyle" },
  { tag: "Skipped meal", category: "lifestyle" },
  { tag: "Eating out", category: "lifestyle" },
  // medical
  { tag: "Headache", category: "medical" },
  { tag: "Cramps", category: "medical" },
  { tag: "Brain fog", category: "medical" },
  { tag: "Stomach upset", category: "medical" },
  { tag: "Allergic flare", category: "medical" },
  // health status
  { tag: "67+ nutrition score", category: "health_status" },
  { tag: "10k+ steps", category: "health_status" },
  { tag: "20+ min cardio", category: "health_status" },
  { tag: "Strength session", category: "health_status" },
  { tag: "Good sleep", category: "health_status" },
  // supplements
  { tag: "Multivitamin", category: "supplements" },
  { tag: "Vitamin D", category: "supplements" },
  { tag: "Omega-3", category: "supplements" },
  { tag: "Creatine", category: "supplements" },
  { tag: "Magnesium", category: "supplements" },
  { tag: "Probiotic", category: "supplements" },
] as const;

const SYSTEM = `You are a habit tagger. Given a single journal entry (food
log, weight log, or free-text note), pick zero to three tags from the
catalog that best describe it. Return JSON ONLY in the schema:
  { "tags": [ { "tag": string, "category": string } ] }
Use the literal tag string from the catalog. Never invent new tags.`;

const Output = z.object({
  tags: z.array(z.object({ tag: z.string(), category: z.string() })),
});

export const classifyJournalEntryTool = defineTool({
  name: "classifyJournalEntry",
  description:
    "Classify a journal entry into 0–3 catalog tags. Persists `journal_tags` " +
    "rows so the Insights tab can correlate them with metric deltas.",
  input: z.object({
    entryId: z.string().uuid(),
    entryKind: z.enum(["food", "weight", "manual"]),
    text: z.string().min(1).max(2000),
    timestamp: z.number(),
    context: z.string().max(500).optional(),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      entryId: { type: "string" },
      entryKind: { type: "string", enum: ["food", "weight", "manual"] },
      text: { type: "string" },
      timestamp: { type: "number" },
      context: { type: "string" },
    },
    required: ["entryId", "entryKind", "text", "timestamp"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const catalogText = TAG_CATALOG.map((t) => `- ${t.tag} (${t.category})`).join("\n");
    const userPrompt = `Catalog:\n${catalogText}\n\nEntry kind: ${args.entryKind}\nEntry text: "${args.text}"\nTimestamp: ${new Date(args.timestamp).toISOString()}\nContext: ${args.context ?? "(none)"}\n\nReturn the JSON now.`;

    const raw = await ctx.llm.completeText({
      task: "cheap",
      system: SYSTEM,
      user: userPrompt,
      maxTokens: 200,
    });

    const parsed = safeParseTags(raw);
    const validTags = parsed.filter((t) =>
      TAG_CATALOG.some((c) => c.tag === t.tag && c.category === t.category)
    );

    const now = Date.now();
    for (const t of validTags) {
      await ctx.db.insert(journalTags).values({
        id: crypto.randomUUID(),
        firebaseUid: ctx.uid,
        entryRefId: args.entryId,
        entryKind: args.entryKind,
        tag: t.tag,
        category: t.category,
        source: "auto",
        createdAt: now,
      });
    }

    return { tags: validTags };
  },
});

function safeParseTags(s: string): Array<{ tag: string; category: string }> {
  try {
    const cleaned = s.replace(/```json|```/g, "").trim();
    const v = JSON.parse(cleaned);
    if (!Array.isArray(v?.tags)) return [];
    return v.tags
      .filter((x: unknown) => typeof x === "object" && x !== null)
      .map((x: { tag?: unknown; category?: unknown }) => ({
        tag: typeof x.tag === "string" ? x.tag : "",
        category: typeof x.category === "string" ? x.category : "",
      }))
      .filter((t: { tag: string; category: string }) => t.tag && t.category);
  } catch {
    return [];
  }
}
