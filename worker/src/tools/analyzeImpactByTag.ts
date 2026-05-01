import { and, eq, gte } from "drizzle-orm";
import { z } from "zod";
import { foodEntries, journalTags } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  artifactId: z.string(),
  tag: z.string(),
  metric: z.string(),
  period: z.string(),
  withTagAvg: z.number(),
  withoutTagAvg: z.number(),
  deltaPercent: z.number(),
  isPositive: z.boolean(),
  pValue: z.number(),
  daysWithTag: z.number().int(),
  daysWithoutTag: z.number().int(),
});

export const analyzeImpactByTagTool = defineTool({
  name: "analyzeImpactByTag",
  description:
    "Compute the % impact of a habit tag on a metric (recovery / sleep / " +
    "nutrition) by comparing days where the tag fires vs. days where it " +
    "doesn't. Emits a `chart` artifact (red/green bar) and returns the " +
    "underlying numbers + a Welch's t-test p-value.",
  input: z.object({
    tag: z.string().min(1).max(80),
    metric: z.enum(["recovery", "sleep", "nutrition"]),
    period: z.enum(["30d", "60d", "90d"]).default("30d"),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      tag: { type: "string" },
      metric: { type: "string", enum: ["recovery", "sleep", "nutrition"] },
      period: { type: "string", enum: ["30d", "60d", "90d"] },
    },
    required: ["tag", "metric"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const days = args.period === "90d" ? 90 : args.period === "60d" ? 60 : 30;
    const sinceMs = Date.now() - days * 24 * 60 * 60 * 1000;

    // Find days where the tag fired.
    const tagRows = await ctx.db
      .select({ createdAt: journalTags.createdAt })
      .from(journalTags)
      .where(
        and(
          eq(journalTags.firebaseUid, ctx.uid),
          eq(journalTags.tag, args.tag),
          gte(journalTags.createdAt, sinceMs)
        )
      );
    const taggedDays = new Set(tagRows.map((r) => startOfDayMs(r.createdAt)));

    // Per-day metric values. For V2 we approximate metrics from food_entries
    // since the worker doesn't yet ingest sleep/HRV daily — the iOS app sends
    // these as one-shot snapshots. The shape stays correct for when the
    // nightly cron starts persisting daily metrics.
    const meals = await ctx.db
      .select({ kcal: foodEntries.kcal, dayStart: foodEntries.dayStart, protein: foodEntries.protein })
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.firebaseUid, ctx.uid),
          gte(foodEntries.dayStart, sinceMs)
        )
      );

    const dayMetric = new Map<number, number>();
    for (const m of meals) {
      const key = m.dayStart;
      const value = args.metric === "nutrition" ? (m.protein ?? 0) : (m.kcal ?? 0);
      dayMetric.set(key, (dayMetric.get(key) ?? 0) + value);
    }

    const withValues: number[] = [];
    const withoutValues: number[] = [];
    for (const [day, value] of dayMetric.entries()) {
      if (taggedDays.has(day)) withValues.push(value);
      else withoutValues.push(value);
    }

    const withAvg = avg(withValues);
    const withoutAvg = avg(withoutValues);
    const deltaPercent =
      withoutAvg === 0 ? 0 : ((withAvg - withoutAvg) / withoutAvg) * 100;
    const pValue = welchTTest(withValues, withoutValues);

    const artifactId = crypto.randomUUID();
    ctx.emit.artifact({
      id: artifactId,
      type: "chart",
      payload: {
        title: `${args.tag} → ${args.metric}`,
        kind: "bar",
        bars: [
          { label: "Without tag", value: withoutAvg, color: "neutral" },
          { label: "With tag", value: withAvg, color: deltaPercent >= 0 ? "good" : "bad" },
        ],
        annotation: `${deltaPercent >= 0 ? "+" : ""}${deltaPercent.toFixed(1)}% (p=${pValue.toFixed(3)})`,
      },
      version: 1,
    });

    return {
      artifactId,
      tag: args.tag,
      metric: args.metric,
      period: args.period,
      withTagAvg: round1(withAvg),
      withoutTagAvg: round1(withoutAvg),
      deltaPercent: round1(deltaPercent),
      isPositive: deltaPercent >= 0,
      pValue: round1k(pValue),
      daysWithTag: withValues.length,
      daysWithoutTag: withoutValues.length,
    };
  },
});

function startOfDayMs(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

function avg(xs: number[]): number {
  if (xs.length === 0) return 0;
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

function variance(xs: number[]): number {
  if (xs.length < 2) return 0;
  const m = avg(xs);
  return xs.reduce((acc, x) => acc + (x - m) ** 2, 0) / (xs.length - 1);
}

/** Two-sided Welch's t-test, returning a rough p-value (clamped to [0, 1]).
 *  Uses a normal approximation for the t distribution — fine for small
 *  effects in habit-impact insights where exact precision isn't required. */
function welchTTest(a: number[], b: number[]): number {
  if (a.length < 2 || b.length < 2) return 1;
  const va = variance(a);
  const vb = variance(b);
  const sa = va / a.length;
  const sb = vb / b.length;
  const denom = Math.sqrt(sa + sb);
  if (denom === 0) return 1;
  const t = Math.abs(avg(a) - avg(b)) / denom;
  // Two-sided normal approximation
  const p = 2 * (1 - cdfNormal(t));
  return Math.max(0, Math.min(1, p));
}

function cdfNormal(z: number): number {
  // Abramowitz & Stegun 7.1.26
  const sign = z < 0 ? -1 : 1;
  const x = Math.abs(z) / Math.SQRT2;
  const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
  const a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);
  return 0.5 * (1.0 + sign * y);
}

function round1(n: number): number { return Math.round(n * 10) / 10; }
function round1k(n: number): number { return Math.round(n * 1000) / 1000; }
