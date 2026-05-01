import { z } from "zod";
import { and, desc, eq } from "drizzle-orm";
import { biomarkers } from "../db/schema";
import { defineTool } from "./types";

const Input = z
  .object({
    category: z.string().optional(),
    limit: z.number().int().min(1).max(500).default(100),
  })
  .strict();

const Item = z.object({
  id: z.string(),
  labReportId: z.string(),
  name: z.string(),
  category: z.string().nullable(),
  value: z.number(),
  unit: z.string(),
  refLow: z.number().nullable(),
  refHigh: z.number().nullable(),
  status: z.string().nullable(),
  takenAt: z.number(),
});

const Output = z.object({
  items: z.array(Item),
});

export const getBiomarkersTool = defineTool({
  name: "get_biomarkers",
  description:
    "Read this user's biomarker measurements (most recent first). Optional category filter (e.g. 'Lipids', 'Inflammation', 'Metabolic').",
  input: Input,
  output: Output,
  parameters: {
    type: "object",
    properties: {
      category: { type: "string" },
      limit: { type: "integer", minimum: 1, maximum: 500, default: 100 },
    },
    required: [],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const where = args.category
      ? and(eq(biomarkers.firebaseUid, ctx.uid), eq(biomarkers.category, args.category))
      : eq(biomarkers.firebaseUid, ctx.uid);
    const rows = await ctx.db
      .select()
      .from(biomarkers)
      .where(where)
      .orderBy(desc(biomarkers.takenAt))
      .limit(args.limit);
    return { items: rows };
  },
});
