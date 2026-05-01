import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { memories } from "../db/schema";
import { defineTool } from "./types";
import { deleteMemoryEmbedding } from "../llm/embed";

const Output = z.object({
  removed: z.boolean(),
  id: z.string(),
});

export const removeMemoryTool = defineTool({
  name: "removeMemory",
  description:
    "Permanently delete a memory by id. Use when the user asks you to forget something or " +
    "when a memory is no longer accurate. The deletion is scoped to the current user.",
  input: z
    .object({
      id: z.string().min(1),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      id: { type: "string", description: "Memory id to delete." },
    },
    required: ["id"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    // The Drizzle D1 driver does not expose `.returning()` for DELETE; we
    // first read the row to confirm ownership and return an honest "removed"
    // boolean.
    const existing = await ctx.db
      .select()
      .from(memories)
      .where(and(eq(memories.id, args.id), eq(memories.firebaseUid, ctx.uid)))
      .limit(1);
    if (existing.length === 0) {
      return { removed: false, id: args.id };
    }
    await ctx.db
      .delete(memories)
      .where(and(eq(memories.id, args.id), eq(memories.firebaseUid, ctx.uid)));
    try {
      await deleteMemoryEmbedding(args.id, ctx.env);
    } catch (err) {
      console.warn(
        "[removeMemory] embedding delete failed:",
        (err as Error).message
      );
    }
    return { removed: true, id: args.id };
  },
});
