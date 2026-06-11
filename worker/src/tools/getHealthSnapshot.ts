import { z } from "zod";
import { defineTool } from "./types";

/**
 * Return the HealthKit snapshot the iOS client supplied with the request.
 *
 * The client passes this in the chat request body so the agent has access to
 * up-to-the-minute data without having to round-trip back through the device.
 * If the client did not include a snapshot (e.g. permissions denied), this
 * returns `{ available: false, snapshot: {} }`.
 */

export const SnapshotShape = z
  .object({
    rhr: z.number().optional(),
    hrv: z.number().optional(),
    sleepHours: z.number().optional(),
    weightKg: z.number().optional(),
    heightCm: z.number().optional(),
    activeEnergyKcal: z.number().optional(),
    steps: z.number().optional(),
    respiratoryRate: z.number().optional(),
    sleepCoreMinutes: z.number().optional(),
    sleepDeepMinutes: z.number().optional(),
    sleepRemMinutes: z.number().optional(),
    hrvBaseline60d: z.number().optional(),
    rhrBaseline60d: z.number().optional(),
    capturedAt: z.string().optional(),
    missing: z.array(z.string()).optional(),
  })
  .passthrough();

const Output = z.object({
  available: z.boolean(),
  snapshot: SnapshotShape,
});

export const getHealthSnapshotTool = defineTool({
  name: "getHealthSnapshot",
  description:
    "Return today's HealthKit snapshot the iOS client included with this turn: resting heart " +
    "rate (rhr), 7-day HRV (hrv), last night's sleepHours plus stage minutes (sleepCoreMinutes, " +
    "sleepDeepMinutes, sleepRemMinutes), respiratoryRate, today's steps and activeEnergyKcal, " +
    "latest weightKg/heightCm, 60-day personal baselines (hrvBaseline60d, rhrBaseline60d), and " +
    "capturedAt. Fields listed in `missing` are unavailable — acknowledge gaps, never invent " +
    "values. Use this before recommending intensity, computing TDEE, or interpreting recovery.",
  input: z.object({}).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {},
    additionalProperties: false,
  },
  async run(_args, ctx) {
    if (!ctx.healthSnapshot) {
      return { available: false, snapshot: {} };
    }
    // Re-validate against the schema so we don't pass garbage to the model
    // even if the iOS client sent unexpected types.
    const parsed = SnapshotShape.safeParse(ctx.healthSnapshot);
    if (!parsed.success) {
      return { available: false, snapshot: {} };
    }
    return { available: true, snapshot: parsed.data };
  },
});
