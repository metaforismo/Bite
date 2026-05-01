import { z } from "zod";
import { and, desc, eq } from "drizzle-orm";
import { artifacts, foodEntries } from "../db/schema";
import { defineTool } from "./types";
import { DEFAULT_MODELS } from "../llm/router";

/**
 * Re-emit a `food_cart` artifact at version+1 with corrected macros.
 *
 * Typical use: user says "actually that was a half portion" — we feed the
 * original entry + the correction text into a small Sonnet call and ask for
 * the corrected JSON. The original D1 row is updated in place; the artifact
 * keeps the same id so the iOS UI patches its existing food cart card.
 */

const ExtractedSchema = z.object({
  dishName: z.string().min(1),
  kcal: z.number().int().min(0).max(10000),
  protein: z.number().min(0).max(500),
  carbs: z.number().min(0).max(1000),
  fat: z.number().min(0).max(500),
  fiber: z.number().min(0).max(200).optional(),
  mealLabel: z
    .enum(["breakfast", "lunch", "dinner", "snack"])
    .optional(),
  badge: z.string().max(40).optional(),
  whyItsGood: z.string().max(280).optional(),
  portionLabel: z.string().max(60).optional(),
});

const Output = z.object({
  artifactId: z.string(),
  version: z.number().int(),
  entryId: z.string(),
  extracted: ExtractedSchema,
});

const CORRECTION_SYSTEM = `You are a precision nutrition extractor. The user has corrected an earlier estimate. Apply their correction to produce a fresh JSON object with the same fields as before.

Output schema:
{
  "dishName": string,
  "kcal": integer,
  "protein": number,  // grams
  "carbs": number,
  "fat": number,
  "fiber": number?,
  "mealLabel": "breakfast"|"lunch"|"dinner"|"snack"?,
  "badge": string?,
  "whyItsGood": string?,
  "portionLabel": string?
}

Macros must be self-consistent: kcal ≈ 4P + 4C + 9F ± 15%. Output ONLY the JSON object.`;

export const correctFoodEntryTool = defineTool({
  name: "correctFoodEntry",
  description:
    "Apply a user-supplied correction to a previously logged food entry: re-estimates the " +
    "macros and re-emits the same artifact id with version+1. Use when the user says things " +
    "like 'half that', 'actually whole milk', 'more like 2 cups', etc.",
  input: z
    .object({
      artifactId: z
        .string()
        .min(1)
        .describe("The artifact id returned by addFoodEntry (e.g. food/<uuid>)."),
      correction: z
        .string()
        .min(1)
        .max(500)
        .describe("Plain-language correction from the user."),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      artifactId: {
        type: "string",
        description: "The food_cart artifact id to revise.",
      },
      correction: {
        type: "string",
        description: "User-supplied correction, e.g. 'half a portion'.",
      },
    },
    required: ["artifactId", "correction"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    // Resolve entry id from artifactId. Convention: artifactId = "food/<uuid>".
    const entryId = args.artifactId.startsWith("food/")
      ? args.artifactId.slice("food/".length)
      : args.artifactId;

    const rows = await ctx.db
      .select()
      .from(foodEntries)
      .where(
        and(eq(foodEntries.id, entryId), eq(foodEntries.firebaseUid, ctx.uid))
      )
      .limit(1);
    const row = rows[0];
    if (!row) {
      throw new Error("entry_not_found_or_unauthorized");
    }

    ctx.emit.thinking({
      id: "food/correct",
      label: "Re-estimating with your correction",
      status: "running",
    });

    const original = {
      dishName: row.dishName ?? row.text,
      kcal: row.kcal ?? 0,
      protein: row.protein ?? 0,
      carbs: row.carbs ?? 0,
      fat: row.fat ?? 0,
      fiber: row.fiber ?? undefined,
      mealLabel: row.mealLabel ?? undefined,
      badge: row.badge ?? undefined,
      whyItsGood: row.whyItsGood ?? undefined,
      portionLabel: row.portionLabel ?? undefined,
    };

    const completion = await ctx.llm.chat({
      model: DEFAULT_MODELS.sonnet,
      messages: [
        { role: "system", content: CORRECTION_SYSTEM },
        {
          role: "user",
          content:
            `Original entry text: ${row.text}\n` +
            `Original estimate: ${JSON.stringify(original)}\n` +
            `User correction: ${args.correction}\n\n` +
            `Return the revised JSON.`,
        },
      ],
      temperature: 0.1,
      maxTokens: 600,
    });

    const extracted = parseExtraction(completion.content);

    ctx.emit.thinking({
      id: "food/correct",
      label: "Re-estimating with your correction",
      status: "done",
    });

    // Update the row.
    await ctx.db
      .update(foodEntries)
      .set({
        dishName: extracted.dishName,
        kcal: extracted.kcal,
        protein: extracted.protein,
        carbs: extracted.carbs,
        fat: extracted.fat,
        fiber: extracted.fiber ?? null,
        mealLabel: extracted.mealLabel ?? null,
        badge: extracted.badge ?? null,
        whyItsGood: extracted.whyItsGood ?? null,
        portionLabel: extracted.portionLabel ?? null,
        correctionText: args.correction,
      })
      .where(
        and(eq(foodEntries.id, entryId), eq(foodEntries.firebaseUid, ctx.uid))
      );

    // Compute next version by reading the latest artifact row with the same id.
    const latest = await ctx.db
      .select()
      .from(artifacts)
      .where(
        and(eq(artifacts.id, args.artifactId), eq(artifacts.firebaseUid, ctx.uid))
      )
      .orderBy(desc(artifacts.version))
      .limit(1);
    const version = (latest[0]?.version ?? 1) + 1;

    ctx.emit.artifact({
      id: args.artifactId,
      type: "food_cart",
      version,
      payload: {
        entryId,
        dishName: extracted.dishName,
        kcal: extracted.kcal,
        protein: extracted.protein,
        carbs: extracted.carbs,
        fat: extracted.fat,
        fiber: extracted.fiber ?? null,
        mealLabel: extracted.mealLabel ?? null,
        badge: extracted.badge ?? null,
        whyItsGood: extracted.whyItsGood ?? null,
        portionLabel: extracted.portionLabel ?? null,
        photoFileId: row.photoFileId ?? null,
        correction: args.correction,
        createdAt: row.createdAt,
      },
    });

    return { artifactId: args.artifactId, version, entryId, extracted };
  },
});

function parseExtraction(raw: string): z.infer<typeof ExtractedSchema> {
  const stripped = raw
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/, "")
    .trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(stripped);
  } catch (err) {
    throw new Error(
      `model returned non-JSON (${(err as Error).message}): ${raw.slice(0, 200)}`
    );
  }
  const check = ExtractedSchema.safeParse(parsed);
  if (!check.success) {
    throw new Error(
      `model output failed schema: ${check.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ")}`
    );
  }
  return check.data;
}
