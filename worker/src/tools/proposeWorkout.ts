import { z } from "zod";
import { defineTool } from "./types";
import { DEFAULT_MODELS } from "../llm/router";

/**
 * Propose a single workout that respects user-supplied constraints.
 * Uses Claude Opus with a strict JSON schema for the response.
 */

const Exercise = z.object({
  name: z.string(),
  sets: z.number().int().min(1).max(10),
  reps: z.string().min(1).max(40), // e.g. "8-10", "to failure", "30s"
  notes: z.string().max(280).optional(),
});

const Workout = z.object({
  title: z.string().min(1).max(120),
  durationMin: z.number().int().min(5).max(240),
  intensity: z.enum(["easy", "moderate", "hard"]),
  warmup: z.array(Exercise).default([]),
  main: z.array(Exercise).min(1),
  cooldown: z.array(Exercise).default([]),
  notes: z.string().max(500).optional(),
});

const Output = z.object({
  workout: Workout,
  artifactId: z.string(),
});

const SYSTEM = `You are an expert evidence-based coach. Produce a single workout that fits the user's constraints. Respond with ONLY a JSON object matching this schema (no markdown, no prose):

{
  "title": string,
  "durationMin": integer,           // total target duration in minutes
  "intensity": "easy"|"moderate"|"hard",
  "warmup": Exercise[],             // may be []
  "main":   Exercise[],             // at least one
  "cooldown": Exercise[],           // may be []
  "notes": string?                  // optional caveats
}
where Exercise = { "name": string, "sets": int, "reps": string, "notes"?: string }

Rules:
- "reps" can be a range ("8-10"), a hold ("30s"), or "to failure".
- Match the user's available equipment, time, and any pain/injury constraints.
- Prefer compounds for hypertrophy/strength; intervals or zone-2 for cardio.
- Don't include sets of 0 or impossible reps.`;

export const proposeWorkoutTool = defineTool({
  name: "proposeWorkout",
  description:
    "Generate a single workout for today (or for a specified focus) that respects the " +
    "user's constraints (time, equipment, body part, injuries). Emits a `workout` artifact " +
    "the iOS UI can render and schedule.",
  input: z
    .object({
      constraints: z
        .object({
          focus: z
            .string()
            .max(120)
            .optional()
            .describe(
              "What to train, e.g. 'upper body push', 'zone 2 run', 'mobility'."
            ),
          durationMin: z.number().int().min(5).max(240).optional(),
          equipment: z.array(z.string()).max(20).optional(),
          avoid: z.array(z.string()).max(20).optional(),
          intensityHint: z.enum(["easy", "moderate", "hard"]).optional(),
        })
        .strict(),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      constraints: {
        type: "object",
        properties: {
          focus: { type: "string" },
          durationMin: { type: "integer", minimum: 5, maximum: 240 },
          equipment: { type: "array", items: { type: "string" } },
          avoid: { type: "array", items: { type: "string" } },
          intensityHint: {
            type: "string",
            enum: ["easy", "moderate", "hard"],
          },
        },
        additionalProperties: false,
      },
    },
    required: ["constraints"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    ctx.emit.thinking({
      id: "workout/draft",
      label: "Drafting workout",
      status: "running",
    });

    const completion = await ctx.llm.chat({
      model: DEFAULT_MODELS.primary, // Claude Opus
      messages: [
        { role: "system", content: SYSTEM },
        {
          role: "user",
          content: `Constraints: ${JSON.stringify(args.constraints)}`,
        },
      ],
      temperature: 0.3,
      maxTokens: 1200,
    });

    const workout = parseWorkout(completion.content);

    const artifactId = `workout/${crypto.randomUUID()}`;
    ctx.emit.artifact({
      id: artifactId,
      type: "workout",
      version: 1,
      payload: workout,
    });

    ctx.emit.thinking({
      id: "workout/draft",
      label: "Drafting workout",
      status: "done",
    });

    return { workout, artifactId };
  },
});

function parseWorkout(raw: string): z.infer<typeof Workout> {
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
  const check = Workout.safeParse(parsed);
  if (!check.success) {
    throw new Error(
      `workout failed schema: ${check.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ")}`
    );
  }
  return check.data;
}
