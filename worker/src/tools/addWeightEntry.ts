import { z } from "zod";
import { defineTool } from "./types";

/**
 * Logs a body-weight measurement. The worker doesn't yet persist a
 * weight history server-side — it just validates the value and emits
 * a `tool_result` event. The iOS `CoachToolDispatcher.mirrorWeight`
 * picks it up and writes a `WeightEntry` to local SwiftData so the
 * Today rings, weight chart, and history reflect the change.
 *
 * (D1-side persistence will land alongside CloudKit sync in a later
 * phase. For now the source of truth is the device.)
 */

const Output = z.object({
  weightKg: z.number(),
  recordedAt: z.number(), // unix ms
});

export const addWeightEntryTool = defineTool({
  name: "addWeightEntry",
  description:
    "Log the user's body weight in kilograms. Use whenever the user says " +
    "things like 'I weigh 78 kg today', 'log my weight as 76.4', or 'I'm " +
    "down to 72.1'. Always pass weight in kg — convert from lb if needed " +
    "(1 lb = 0.453592 kg).",
  input: z.object({
    weightKg: z.number().min(20).max(400),
    recordedAt: z.number().optional(),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      weightKg: {
        type: "number",
        description: "Body weight in kilograms (20–400).",
      },
      recordedAt: {
        type: "number",
        description: "Unix epoch ms; defaults to now.",
      },
    },
    required: ["weightKg"],
    additionalProperties: false,
  },
  async run(args, _ctx) {
    return {
      weightKg: args.weightKg,
      recordedAt: args.recordedAt ?? Date.now(),
    };
  },
});
