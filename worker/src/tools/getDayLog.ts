import { z } from "zod";
import { and, asc, eq, gte, lt } from "drizzle-orm";
import { foodEntries } from "../db/schema";
import { defineTool } from "./types";

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD");

const FoodEntryDTO = z.object({
  id: z.string(),
  text: z.string(),
  dishName: z.string().nullable(),
  kcal: z.number().nullable(),
  protein: z.number().nullable(),
  carbs: z.number().nullable(),
  fat: z.number().nullable(),
  fiber: z.number().nullable(),
  mealLabel: z.string().nullable(),
  badge: z.string().nullable(),
  whyItsGood: z.string().nullable(),
  portionLabel: z.string().nullable(),
  photoFileId: z.string().nullable(),
  createdAt: z.number(),
});
export type FoodEntryDTO = z.infer<typeof FoodEntryDTO>;

const Output = z.object({
  date: dateString,
  totals: z.object({
    kcal: z.number(),
    protein: z.number(),
    carbs: z.number(),
    fat: z.number(),
    fiber: z.number(),
  }),
  entries: z.array(FoodEntryDTO),
});

/** UTC midnight (ms) for a YYYY-MM-DD string. */
function dayStartMs(date: string): number {
  // Parsing as `YYYY-MM-DDT00:00:00Z` keeps everything UTC so the day boundary
  // is consistent regardless of the worker's host timezone.
  const t = Date.parse(`${date}T00:00:00Z`);
  if (Number.isNaN(t)) throw new Error(`invalid date: ${date}`);
  return t;
}

export const getDayLogTool = defineTool({
  name: "getDayLog",
  description:
    "Return the user's food entries for a single calendar day (UTC), with macro totals. " +
    "Use this when the user asks 'what did I eat today/yesterday' or before estimating how " +
    "much room they have left in the day.",
  input: z
    .object({
      date: dateString.describe("ISO calendar date in YYYY-MM-DD form (UTC)."),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      date: {
        type: "string",
        description: "ISO calendar date in YYYY-MM-DD form (UTC).",
        pattern: "^\\d{4}-\\d{2}-\\d{2}$",
      },
    },
    required: ["date"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const start = dayStartMs(args.date);
    const end = start + 24 * 60 * 60 * 1000;
    const rows = await ctx.db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.firebaseUid, ctx.uid),
          gte(foodEntries.dayStart, start),
          lt(foodEntries.dayStart, end)
        )
      )
      .orderBy(asc(foodEntries.createdAt));

    const totals = { kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 };
    const entries: FoodEntryDTO[] = rows.map((r) => {
      totals.kcal += r.kcal ?? 0;
      totals.protein += r.protein ?? 0;
      totals.carbs += r.carbs ?? 0;
      totals.fat += r.fat ?? 0;
      totals.fiber += r.fiber ?? 0;
      return {
        id: r.id,
        text: r.text,
        dishName: r.dishName ?? null,
        kcal: r.kcal ?? null,
        protein: r.protein ?? null,
        carbs: r.carbs ?? null,
        fat: r.fat ?? null,
        fiber: r.fiber ?? null,
        mealLabel: r.mealLabel ?? null,
        badge: r.badge ?? null,
        whyItsGood: r.whyItsGood ?? null,
        portionLabel: r.portionLabel ?? null,
        photoFileId: r.photoFileId ?? null,
        createdAt: r.createdAt,
      };
    });

    return { date: args.date, totals, entries };
  },
});
