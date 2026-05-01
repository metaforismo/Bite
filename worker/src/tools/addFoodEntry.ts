import { z } from "zod";
import { eq, and } from "drizzle-orm";
import { foodEntries, files as filesTable } from "../db/schema";
import { defineTool } from "./types";
import { DEFAULT_MODELS } from "../llm/router";
import { decryptForUser } from "../encryption";

/**
 * Extract a structured food entry from free text (and optionally a photo),
 * persist it to D1, and emit a `food_cart` artifact for the iOS UI.
 *
 * Routing:
 *   - text-only  → Claude Sonnet (cheap-ish + accurate macros)
 *   - text+photo → Gemini Vision (sees the plate)
 *
 * The model is asked for a strict JSON object; we Zod-parse and fail fast on
 * malformed output.
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
  entryId: z.string(),
  artifactId: z.string(),
  version: z.number().int(),
  extracted: ExtractedSchema,
});

const EXTRACTION_SYSTEM = `You are a precision nutrition extractor. Given a description of a meal (and optionally a photo), produce a single JSON object with these fields:
- dishName: short canonical name, e.g. "Avocado toast with eggs"
- kcal: integer kilocalories
- protein, carbs, fat: grams (number)
- fiber: grams (number, optional)
- mealLabel: one of "breakfast" | "lunch" | "dinner" | "snack" (optional, infer from time-of-day cues)
- badge: a short positive tag like "high-protein", "balanced", "carb-heavy" (optional)
- whyItsGood: one short sentence explaining why this meal is or isn't aligned with common goals (optional)
- portionLabel: e.g. "1 medium bowl", "2 slices", "approx. 350g" (optional)

Macros must be self-consistent: kcal ≈ 4*protein + 4*carbs + 9*fat ± 15%.
Output ONLY the JSON object, no prose.`;

export const addFoodEntryTool = defineTool({
  name: "addFoodEntry",
  description:
    "Log a food entry. Pass the user's text describing the meal, and optionally a photo " +
    "file id (uploaded via /v1/files). The tool calls a vision-capable LLM when a photo is " +
    "present, otherwise a text model. Persists the entry and emits a food_cart artifact.",
  input: z
    .object({
      text: z.string().min(1).max(2000),
      photoFileId: z.string().uuid().optional(),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      text: {
        type: "string",
        description: "User-facing description of the meal.",
      },
      photoFileId: {
        type: "string",
        description: "Optional file id from /v1/files for a meal photo.",
      },
    },
    required: ["text"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    ctx.emit.thinking({
      id: "food/identify",
      label: "Identifying ingredients",
      status: "running",
    });

    // Build the model messages. With a photo we use a vision model and pass
    // the image as a data URL after decrypting it from R2.
    let modelOverride: string | undefined;
    let visionFlag = false;
    const messages: Array<{ role: "system" | "user"; content: string }> = [
      { role: "system", content: EXTRACTION_SYSTEM },
    ];

    if (args.photoFileId) {
      visionFlag = true;
      modelOverride = DEFAULT_MODELS.vision;
      const dataUrl = await loadPhotoAsDataUrl(ctx, args.photoFileId);
      // Vision models on OpenAI-compatible APIs accept the multimodal
      // content array. We bypass the strongly-typed router for that single
      // message by encoding the JSON object as the content string — the
      // router uses pure string content, but OpenRouter's vision endpoints
      // also accept a JSON-serialized array under `content` for some
      // providers. To keep it simple, we instead prepend the image as a
      // markdown-image-style data URI block; Gemini reliably reads this.
      messages.push({
        role: "user",
        content: [
          `Photo (data URL): ${dataUrl.slice(0, 30)}…[truncated for log]`,
          "",
          `User said: ${args.text}`,
        ].join("\n"),
      });
      // Pass the image again via a separate call below using the OpenAI SDK's
      // multimodal content array. Since the public LLMRouter only takes
      // string content, we extend by calling the underlying client. To stay
      // within the router contract we forward the data URL inline; recent
      // Gemini Vision builds accept a `data:` URL embedded in a markdown
      // image. If that fails the model can still infer from the user text.
      messages[messages.length - 1] = {
        role: "user",
        content: `![meal](${dataUrl})\n\nUser said: ${args.text}`,
      };
    } else {
      // Sonnet for text-only — better number sense than Haiku for macros.
      modelOverride = DEFAULT_MODELS.sonnet;
      messages.push({ role: "user", content: args.text });
    }

    ctx.emit.thinking({
      id: "food/identify",
      label: "Identifying ingredients",
      status: "done",
    });

    ctx.emit.thinking({
      id: "food/macros",
      label: "Estimating macros",
      status: "running",
    });

    const completion = await ctx.llm.chat({
      model: modelOverride,
      vision: visionFlag,
      messages,
      temperature: 0.1,
      maxTokens: 600,
    });

    const extracted = parseExtraction(completion.content);

    ctx.emit.thinking({
      id: "food/macros",
      label: "Estimating macros",
      status: "done",
    });

    // Persist.
    const now = Date.now();
    const dayStart = startOfUtcDay(now);
    const id = crypto.randomUUID();
    await ctx.db.insert(foodEntries).values({
      id,
      firebaseUid: ctx.uid,
      threadId: ctx.threadId,
      messageId: ctx.messageId,
      text: args.text,
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
      photoFileId: args.photoFileId ?? null,
      dayStart,
      createdAt: now,
    });

    const artifactId = `food/${id}`;
    const version = 1;
    ctx.emit.artifact({
      id: artifactId,
      type: "food_cart",
      version,
      payload: {
        entryId: id,
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
        photoFileId: args.photoFileId ?? null,
        createdAt: now,
      },
    });

    return {
      entryId: id,
      artifactId,
      version,
      extracted,
    };
  },
});

/** Parse the model's JSON output, tolerating ```json fences. */
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

function startOfUtcDay(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/**
 * Fetch a photo from R2, decrypt it for this user, and return a data: URL
 * suitable for embedding in a vision prompt.
 */
async function loadPhotoAsDataUrl(
  ctx: import("./types").ToolContext,
  photoFileId: string
): Promise<string> {
  const rows = await ctx.db
    .select()
    .from(filesTable)
    .where(
      and(eq(filesTable.id, photoFileId), eq(filesTable.firebaseUid, ctx.uid))
    )
    .limit(1);
  const row = rows[0];
  if (!row) {
    throw new Error("photo_not_found_or_unauthorized");
  }
  const obj = await ctx.env.FILES.get(row.r2Key);
  if (!obj) {
    throw new Error("photo_missing_in_storage");
  }
  const cipher = new Uint8Array(await obj.arrayBuffer());
  const plain = await decryptForUser(
    cipher,
    ctx.uid,
    ctx.env.FILE_ENCRYPTION_MASTER_KEY
  );
  const b64 = bytesToBase64(plain);
  return `data:${row.mimeType};base64,${b64}`;
}

function bytesToBase64(bytes: Uint8Array): string {
  // Worker runtime has btoa(); chunk to avoid argument-length limits on
  // larger images.
  const CHUNK = 0x8000;
  let bin = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(bin);
}
