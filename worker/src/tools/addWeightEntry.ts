import { z } from "zod";
import { weightEntries } from "../db/schema";
import { defineTool } from "./types";

/**
 * Logs a body-weight measurement. Persists to D1 (`weight_entries`) and
 * emits a `tool_result` event; the iOS `CoachToolDispatcher.mirrorWeight`
 * additionally writes a local `WeightEntry` so the Today rings, weight
 * chart, and history reflect the change immediately.
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
  async run(args, ctx) {
    const recordedAt = args.recordedAt ?? Date.now();
    await ctx.db.insert(weightEntries).values({
      id: crypto.randomUUID(),
      firebaseUid: ctx.uid,
      weightKg: args.weightKg,
      recordedAt,
      createdAt: Date.now(),
    });
    return {
      weightKg: args.weightKg,
      recordedAt,
    };
  },
});
