import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { cycleEntries } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  id: z.string(),
  date: z.string(),
  flowLevel: z.number().int().min(0).max(3),
  symptoms: z.array(z.string()),
  source: z.string(),
});

export const addCycleEntryTool = defineTool({
  name: "addCycleEntry",
  description:
    "Log a single day of menstrual cycle data — flow level (0=none, 1=light, " +
    "2=medium, 3=heavy) plus an optional list of symptoms (e.g. 'Cramps', " +
    "'Headache'). Updates the row in place when one already exists for that " +
    "(date, source='manual') pair.",
  input: z.object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD"),
    flowLevel: z.number().int().min(0).max(3),
    symptoms: z.array(z.string().max(40)).max(20).default([]),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      date: { type: "string", description: "YYYY-MM-DD (UTC)" },
      flowLevel: { type: "integer", minimum: 0, maximum: 3 },
      symptoms: { type: "array", items: { type: "string" } },
    },
    required: ["date", "flowLevel"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const dateMs = isoToUtcMs(args.date);
    const symptomsJson = JSON.stringify(args.symptoms ?? []);

    const existing = await ctx.db
      .select()
      .from(cycleEntries)
      .where(
        and(
          eq(cycleEntries.firebaseUid, ctx.uid),
          eq(cycleEntries.date, dateMs),
          eq(cycleEntries.source, "manual")
        )
      )
      .limit(1);

    if (existing.length > 0) {
      const row = existing[0];
      await ctx.db
        .update(cycleEntries)
        .set({ flowLevel: args.flowLevel, symptomsJSON: symptomsJson })
        .where(eq(cycleEntries.id, row.id));
      return {
        id: row.id,
        date: args.date,
        flowLevel: args.flowLevel,
        symptoms: args.symptoms ?? [],
        source: "manual",
      };
    }

    const id = crypto.randomUUID();
    await ctx.db.insert(cycleEntries).values({
      id,
      firebaseUid: ctx.uid,
      date: dateMs,
      flowLevel: args.flowLevel,
      symptomsJSON: symptomsJson,
      source: "manual",
    });
    return {
      id,
      date: args.date,
      flowLevel: args.flowLevel,
      symptoms: args.symptoms ?? [],
      source: "manual",
    };
  },
});

function isoToUtcMs(iso: string): number {
  const [y, m, d] = iso.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}
