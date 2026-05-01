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

const SnapshotShape = z
  .object({
    date: z.string().optional(),
    steps: z.number().optional(),
    activeKcal: z.number().optional(),
    restingKcal: z.number().optional(),
    sleepHours: z.number().optional(),
    weightKg: z.number().optional(),
    heartRateAvg: z.number().optional(),
    hrv: z.number().optional(),
    vo2Max: z.number().optional(),
    workouts: z
      .array(
        z.object({
          type: z.string(),
          durationMin: z.number(),
          kcal: z.number().optional(),
        })
      )
      .optional(),
  })
  .passthrough();

const Output = z.object({
  available: z.boolean(),
  snapshot: SnapshotShape,
});

export const getHealthSnapshotTool = defineTool({
  name: "getHealthSnapshot",
  description:
    "Return today's HealthKit snapshot the iOS client included with this turn: steps, " +
    "active/resting kcal, sleep hours, weight, HR/HRV, VO2max, recent workouts. Use this " +
    "before recommending intensity, computing TDEE, or interpreting recovery.",
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
