import { z } from "zod";
import { and, asc, eq, gte, lt } from "drizzle-orm";
import { foodEntries } from "../db/schema";
import { defineTool } from "./types";

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD");

const DailyTotals = z.object({
  date: dateString,
  kcal: z.number(),
  protein: z.number(),
  carbs: z.number(),
  fat: z.number(),
  fiber: z.number(),
  count: z.number().int(),
});

const Output = z.object({
  start: dateString,
  end: dateString,
  days: z.array(DailyTotals),
});

function dayStartMs(date: string): number {
  const t = Date.parse(`${date}T00:00:00Z`);
  if (Number.isNaN(t)) throw new Error(`invalid date: ${date}`);
  return t;
}

function isoDay(ms: number): string {
  const d = new Date(ms);
  return d.toISOString().slice(0, 10);
}

export const getRangeTool = defineTool({
  name: "getRange",
  description:
    "Return per-day macro totals over an inclusive date range. The range is capped at " +
    "62 days; if you need a wider window, query in chunks. Use this for trend analysis, " +
    "weekly summaries, or before calling analyzeImpact/predict.",
  input: z
    .object({
      start: dateString,
      end: dateString,
    })
    .strict()
    .refine((v) => dayStartMs(v.start) <= dayStartMs(v.end), {
      message: "start must be <= end",
    }),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      start: {
        type: "string",
        pattern: "^\\d{4}-\\d{2}-\\d{2}$",
        description: "Inclusive start date (UTC, YYYY-MM-DD).",
      },
      end: {
        type: "string",
        pattern: "^\\d{4}-\\d{2}-\\d{2}$",
        description: "Inclusive end date (UTC, YYYY-MM-DD).",
      },
    },
    required: ["start", "end"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const startMs = dayStartMs(args.start);
    const endMsExclusive = dayStartMs(args.end) + 24 * 60 * 60 * 1000;
    const days = Math.round(
      (endMsExclusive - startMs) / (24 * 60 * 60 * 1000)
    );
    if (days > 62) {
      throw new Error("range_too_wide: maximum 62 days");
    }

    const rows = await ctx.db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.firebaseUid, ctx.uid),
          gte(foodEntries.dayStart, startMs),
          lt(foodEntries.dayStart, endMsExclusive)
        )
      )
      .orderBy(asc(foodEntries.dayStart));

    // Aggregate.
    const buckets = new Map<
      string,
      { kcal: number; protein: number; carbs: number; fat: number; fiber: number; count: number }
    >();
    for (const r of rows) {
      const date = isoDay(r.dayStart);
      const b =
        buckets.get(date) ??
        { kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, count: 0 };
      b.kcal += r.kcal ?? 0;
      b.protein += r.protein ?? 0;
      b.carbs += r.carbs ?? 0;
      b.fat += r.fat ?? 0;
      b.fiber += r.fiber ?? 0;
      b.count += 1;
      buckets.set(date, b);
    }

    // Fill empty days so callers get a contiguous timeseries.
    const out: z.infer<typeof DailyTotals>[] = [];
    for (let t = startMs; t < endMsExclusive; t += 24 * 60 * 60 * 1000) {
      const date = isoDay(t);
      const b =
        buckets.get(date) ??
        { kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, count: 0 };
      out.push({ date, ...b });
    }

    return { start: args.start, end: args.end, days: out };
  },
});
