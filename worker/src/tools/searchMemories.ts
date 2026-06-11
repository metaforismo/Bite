import { z } from "zod";
import { and, desc, eq, inArray, like, or } from "drizzle-orm";
import { memories } from "../db/schema";
import { defineTool, type ToolContext } from "./types";
import { queryMemories } from "../llm/embed";

const Memory = z.object({
  id: z.string(),
  category: z.string(),
  text: z.string(),
  score: z.number().nullable(),
});

const Output = z.object({
  query: z.string(),
  hits: z.array(Memory),
});

export const searchMemoriesTool = defineTool({
  name: "searchMemories",
  description:
    "Semantic search over the user's saved memories (preferences, constraints, goals). " +
    "Returns up to top-k matches with their category and original text. Use this to ground " +
    "an answer in stable user facts before responding.",
  input: z
    .object({
      query: z.string().min(1).max(500),
      topK: z.number().int().min(1).max(20).default(5).optional(),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      query: {
        type: "string",
        description:
          "Natural-language question or topic to search memories for.",
      },
      topK: {
        type: "integer",
        description: "Maximum number of memories to return (1-20, default 5).",
        minimum: 1,
        maximum: 20,
      },
    },
    required: ["query"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const topK = args.topK ?? 5;
    let hits: { id: string; score: number; category?: string; text?: string }[] = [];
    try {
      hits = await queryMemories(ctx.uid, args.query, topK, ctx.env);
    } catch (err) {
      // Vectorize is allowed to soft-fail — fall back to plain text match.
      console.warn("[searchMemories] vector query failed:", (err as Error).message);
      return { query: args.query, hits: await textFallback(ctx, args.query, topK) };
    }
    if (hits.length === 0) {
      return { query: args.query, hits: await textFallback(ctx, args.query, topK) };
    }
    // Re-fetch from D1 so we return the canonical (possibly-edited) text and
    // verify ownership.
    const ids = hits.map((h) => h.id);
    const rows = await ctx.db
      .select()
      .from(memories)
      .where(and(eq(memories.firebaseUid, ctx.uid), inArray(memories.id, ids)));
    const byId = new Map(rows.map((r) => [r.id, r]));
    return {
      query: args.query,
      hits: hits
        .map((h) => {
          const row = byId.get(h.id);
          if (!row) return null;
          return {
            id: row.id,
            category: row.category,
            text: row.text,
            score: h.score as number | null,
          };
        })
        .filter((m): m is { id: string; category: string; text: string; score: number | null } => m !== null),
    };
  },
});

/** Keyword fallback when semantic search is unavailable or returns nothing. */
async function textFallback(
  ctx: ToolContext,
  query: string,
  topK: number
): Promise<{ id: string; category: string; text: string; score: number | null }[]> {
  const terms = query
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length >= 3)
    .slice(0, 5);
  if (terms.length === 0) return [];
  const rows = await ctx.db
    .select()
    .from(memories)
    .where(
      and(
        eq(memories.firebaseUid, ctx.uid),
        or(...terms.map((t) => like(memories.text, `%${t}%`)))
      )
    )
    .orderBy(desc(memories.updatedAt))
    .limit(topK);
  return rows.map((r) => ({
    id: r.id,
    category: r.category,
    text: r.text,
    score: null,
  }));
}
