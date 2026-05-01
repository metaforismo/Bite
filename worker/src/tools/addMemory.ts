import { z } from "zod";
import { memories } from "../db/schema";
import { defineTool } from "./types";
import { upsertMemoryEmbedding } from "../llm/embed";

const MEMORY_CATEGORIES = [
  "Goals",
  "Nutrition",
  "Exercise Preferences",
  "Barriers",
  "Dislikes",
  "Recovery",
  "Skincare",
  "Weight",
] as const;

const Output = z.object({
  id: z.string(),
  category: z.string(),
  text: z.string(),
  createdAt: z.number(),
});

export const addMemoryTool = defineTool({
  name: "addMemory",
  description:
    "Save a stable user fact as a memory. Use sparingly: only for things that are unlikely " +
    "to change soon (preferences, constraints, goals, equipment). One sentence per memory.",
  input: z
    .object({
      category: z.enum(MEMORY_CATEGORIES),
      text: z.string().min(3).max(280),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      category: {
        type: "string",
        description: "Memory category.",
        enum: [...MEMORY_CATEGORIES],
      },
      text: {
        type: "string",
        description: "One-sentence canonical fact about the user.",
      },
    },
    required: ["category", "text"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const id = crypto.randomUUID();
    const now = Date.now();
    await ctx.db.insert(memories).values({
      id,
      firebaseUid: ctx.uid,
      category: args.category,
      text: args.text,
      createdAt: now,
      updatedAt: now,
    });
    // Best-effort embedding upsert. If Vectorize is unavailable we keep the
    // D1 row so the next search still returns text matches via fallback.
    try {
      await upsertMemoryEmbedding(ctx.uid, id, args.text, args.category, ctx.env);
    } catch (err) {
      console.warn(
        "[addMemory] embedding upsert failed:",
        (err as Error).message
      );
    }
    return { id, category: args.category, text: args.text, createdAt: now };
  },
});
