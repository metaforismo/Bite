import { z } from "zod";
import { drinks } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  id: z.string(),
  kind: z.enum(["water", "caffeine"]),
  volumeMl: z.number().nullable(),
  caffeineMg: z.number().nullable(),
  label: z.string().nullable(),
  timestamp: z.number(),
});

export const addDrinkTool = defineTool({
  name: "addDrink",
  description:
    "Log a single drink — either water (with volumeMl) or a caffeinated drink " +
    "(with caffeineMg + optional label). Use this whenever the user mentions " +
    "drinking water, coffee, tea, espresso, energy drinks, etc.",
  input: z
    .object({
      kind: z.enum(["water", "caffeine"]),
      volumeMl: z.number().positive().max(5000).optional(),
      caffeineMg: z.number().nonnegative().max(1000).optional(),
      label: z.string().max(60).optional(),
    })
    .strict()
    .refine(
      (a) => (a.kind === "water" ? typeof a.volumeMl === "number" : true),
      { message: "water drinks require volumeMl" }
    )
    .refine(
      (a) => (a.kind === "caffeine" ? typeof a.caffeineMg === "number" : true),
      { message: "caffeine drinks require caffeineMg" }
    ),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      kind: { type: "string", enum: ["water", "caffeine"] },
      volumeMl: { type: "number", description: "milliliters of water; required when kind='water'" },
      caffeineMg: { type: "number", description: "mg of caffeine; required when kind='caffeine'" },
      label: { type: "string", description: "Drink name e.g. 'Coffee', 'Espresso', 'Cold brew'" },
    },
    required: ["kind"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const id = crypto.randomUUID();
    const now = Date.now();
    const dayStart = startOfDayMs(now);
    await ctx.db.insert(drinks).values({
      id,
      firebaseUid: ctx.uid,
      kind: args.kind,
      volumeMl: args.volumeMl ?? null,
      caffeineMg: args.caffeineMg ?? null,
      label: args.label ?? null,
      timestamp: now,
      dayStart,
    });
    return {
      id,
      kind: args.kind,
      volumeMl: args.volumeMl ?? null,
      caffeineMg: args.caffeineMg ?? null,
      label: args.label ?? null,
      timestamp: now,
    };
  },
});

function startOfDayMs(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}
