import { z } from "zod";
import { defineTool } from "./types";
import { getRangeTool } from "./getRange";

/**
 * Simple linear-regression forecast for a metric over the next `horizon`
 * days. Emits two artifacts:
 *   - chart: a line with history + projection
 *   - confidence_dial: a 0-1 confidence value derived from R^2 of the fit
 */

const Metric = z.enum(["kcal", "protein", "carbs", "fat", "fiber"]);

const Output = z.object({
  metric: Metric,
  horizonDays: z.number().int(),
  slopePerDay: z.number(),
  intercept: z.number(),
  r2: z.number(),
  history: z.array(z.object({ date: z.string(), value: z.number() })),
  projection: z.array(z.object({ date: z.string(), value: z.number() })),
  artifactId: z.string(),
  confidenceArtifactId: z.string(),
});

function isoDay(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export const predictTool = defineTool({
  name: "predict",
  description:
    "Predict the next N days of a metric (kcal/protein/carbs/fat/fiber) by linear regression " +
    "on the user's last 30 days. Emits a chart artifact (history + projection) and a " +
    "confidence_dial artifact derived from R^2.",
  input: z
    .object({
      metric: Metric,
      horizon: z
        .number()
        .int()
        .min(1)
        .max(30)
        .describe("How many days into the future to project (1-30)."),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      metric: {
        type: "string",
        enum: ["kcal", "protein", "carbs", "fat", "fiber"],
        description: "Macro to predict.",
      },
      horizon: {
        type: "integer",
        description: "Number of days to project (1-30).",
        minimum: 1,
        maximum: 30,
      },
    },
    required: ["metric", "horizon"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    ctx.emit.thinking({
      id: "predict/fit",
      label: "Fitting recent trend",
      status: "running",
    });

    const today = new Date();
    const endDate = new Date(
      Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
    );
    const startDate = new Date(endDate.getTime() - 29 * 24 * 60 * 60 * 1000);
    const range = await getRangeTool.run(
      { start: isoDay(startDate), end: isoDay(endDate) },
      ctx
    );
    const history = range.days.map((d) => ({
      date: d.date,
      value: (d as Record<string, number | string>)[args.metric] as number,
    }));

    const xs = history.map((_, i) => i);
    const ys = history.map((h) => h.value);
    const fit = linreg(xs, ys);

    const projection: { date: string; value: number }[] = [];
    for (let i = 1; i <= args.horizon; i++) {
      const d = new Date(endDate.getTime() + i * 24 * 60 * 60 * 1000);
      const x = history.length - 1 + i;
      const y = fit.intercept + fit.slope * x;
      projection.push({ date: isoDay(d), value: Math.max(0, y) });
    }

    const artifactId = `predict/${args.metric}/${Date.now()}`;
    ctx.emit.artifact({
      id: artifactId,
      type: "chart",
      version: 1,
      payload: {
        chartType: "line",
        title: `${args.metric} forecast — next ${args.horizon}d`,
        metric: args.metric,
        unit: args.metric === "kcal" ? "kcal" : "g",
        history,
        projection,
        slopePerDay: fit.slope,
        r2: fit.r2,
      },
    });

    const confidenceArtifactId = `confidence/${artifactId}`;
    ctx.emit.artifact({
      id: confidenceArtifactId,
      type: "confidence_dial",
      version: 1,
      payload: {
        title: "Forecast confidence",
        // Map R^2 (which can be very small for noisy logs) into a more
        // user-readable 0-1 with a floor — we don't want to scare the user
        // with "0.02" on a real but noisy trend.
        confidence: Math.min(1, Math.max(0.1, Math.abs(fit.r2))),
        rationale:
          "Linear fit over your last 30 days. Higher = more consistent recent pattern.",
      },
    });

    ctx.emit.thinking({
      id: "predict/fit",
      label: "Fitting recent trend",
      status: "done",
    });

    return {
      metric: args.metric,
      horizonDays: args.horizon,
      slopePerDay: fit.slope,
      intercept: fit.intercept,
      r2: fit.r2,
      history,
      projection,
      artifactId,
      confidenceArtifactId,
    };
  },
});

export function linreg(
  xs: number[],
  ys: number[]
): { slope: number; intercept: number; r2: number } {
  const n = xs.length;
  if (n === 0) return { slope: 0, intercept: 0, r2: 0 };
  if (n === 1) return { slope: 0, intercept: ys[0]!, r2: 0 };
  const meanX = xs.reduce((a, b) => a + b, 0) / n;
  const meanY = ys.reduce((a, b) => a + b, 0) / n;
  let sxy = 0;
  let sxx = 0;
  let syy = 0;
  for (let i = 0; i < n; i++) {
    const dx = xs[i]! - meanX;
    const dy = ys[i]! - meanY;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  const slope = sxx === 0 ? 0 : sxy / sxx;
  const intercept = meanY - slope * meanX;
  const r2 = sxx === 0 || syy === 0 ? 0 : (sxy * sxy) / (sxx * syy);
  return { slope, intercept, r2 };
}
