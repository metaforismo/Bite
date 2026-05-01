import { z } from "zod";
import { defineTool } from "./types";
import { getRangeTool } from "./getRange";

/**
 * Compute basic descriptive stats over a metric ("kcal", "protein", etc.)
 * over a recent period and emit a chart artifact (bar by default, box if
 * the period is long enough).
 *
 * For now `metric` is restricted to fields we actually have in `food_entries`;
 * future versions can read from biomarkers or HealthKit timeseries.
 */

const Metric = z.enum(["kcal", "protein", "carbs", "fat", "fiber"]);
const Period = z.enum(["7d", "14d", "30d", "60d"]);

const Stats = z.object({
  count: z.number(),
  sum: z.number(),
  mean: z.number(),
  median: z.number(),
  p25: z.number(),
  p75: z.number(),
  min: z.number(),
  max: z.number(),
  stddev: z.number(),
});

const Output = z.object({
  metric: Metric,
  period: Period,
  start: z.string(),
  end: z.string(),
  stats: Stats,
  artifactId: z.string(),
});

const PERIOD_DAYS: Record<z.infer<typeof Period>, number> = {
  "7d": 7,
  "14d": 14,
  "30d": 30,
  "60d": 60,
};

function isoDay(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export const analyzeImpactTool = defineTool({
  name: "analyzeImpact",
  description:
    "Run basic descriptive statistics over a metric (kcal/protein/carbs/fat/fiber) for the " +
    "user's recent food log. Emits a chart artifact: 'bar' for short periods, 'box' for " +
    "30+ days. Use to answer questions like 'what's my average protein this week?'.",
  input: z
    .object({
      metric: Metric,
      period: Period,
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      metric: {
        type: "string",
        enum: ["kcal", "protein", "carbs", "fat", "fiber"],
        description: "Macro to summarize.",
      },
      period: {
        type: "string",
        enum: ["7d", "14d", "30d", "60d"],
        description: "Window length (looking back from today, UTC).",
      },
    },
    required: ["metric", "period"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    ctx.emit.thinking({
      id: "impact/compute",
      label: `Crunching ${args.metric} over ${args.period}`,
      status: "running",
    });

    const days = PERIOD_DAYS[args.period];
    const today = new Date();
    const endDate = new Date(
      Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
    );
    const startDate = new Date(endDate.getTime() - (days - 1) * 24 * 60 * 60 * 1000);
    const start = isoDay(startDate);
    const end = isoDay(endDate);

    // Reuse the getRange tool internally so the aggregation logic stays in
    // one place.
    const range = await getRangeTool.run({ start, end }, ctx);

    const series = range.days.map((d) => ({
      date: d.date,
      // d is typed as the inferred output (numeric fields), so dynamic
      // indexing is safe here.
      value: (d as Record<string, number | string>)[args.metric] as number,
    }));

    const values = series.map((s) => s.value);
    const stats = computeStats(values);

    const chartType = days >= 30 ? "box" : "bar";
    const artifactId = `impact/${args.metric}/${args.period}/${Date.now()}`;
    ctx.emit.artifact({
      id: artifactId,
      type: "chart",
      version: 1,
      payload: {
        chartType,
        title: `${args.metric} — last ${args.period}`,
        metric: args.metric,
        unit: args.metric === "kcal" ? "kcal" : "g",
        series,
        stats,
        period: args.period,
      },
    });

    ctx.emit.thinking({
      id: "impact/compute",
      label: `Crunching ${args.metric} over ${args.period}`,
      status: "done",
    });

    return {
      metric: args.metric,
      period: args.period,
      start,
      end,
      stats,
      artifactId,
    };
  },
});

export function computeStats(values: number[]): z.infer<typeof Stats> {
  if (values.length === 0) {
    return {
      count: 0,
      sum: 0,
      mean: 0,
      median: 0,
      p25: 0,
      p75: 0,
      min: 0,
      max: 0,
      stddev: 0,
    };
  }
  const sorted = [...values].sort((a, b) => a - b);
  const sum = values.reduce((a, b) => a + b, 0);
  const mean = sum / values.length;
  const variance =
    values.reduce((acc, v) => acc + (v - mean) ** 2, 0) / values.length;
  const stddev = Math.sqrt(variance);
  return {
    count: values.length,
    sum,
    mean,
    median: percentile(sorted, 0.5),
    p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75),
    min: sorted[0]!,
    max: sorted[sorted.length - 1]!,
    stddev,
  };
}

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const idx = (sorted.length - 1) * p;
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo]!;
  const w = idx - lo;
  return sorted[lo]! * (1 - w) + sorted[hi]! * w;
}
