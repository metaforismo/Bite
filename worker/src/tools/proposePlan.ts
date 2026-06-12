import { z } from "zod";
import { plans } from "../db/schema";
import { defineTool } from "./types";
import { DEFAULT_MODELS } from "../llm/router";

/**
 * Generate a multi-week training plan via the primary reasoning model, persist it to D1, and
 * emit a `training_plan` artifact.
 */

const Session = z.object({
  day: z.enum([
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ]),
  title: z.string().min(1).max(120),
  durationMin: z.number().int().min(10).max(240),
  focus: z.string().min(1).max(120),
  notes: z.string().max(400).optional(),
});

const Week = z.object({
  index: z.number().int().min(1),
  theme: z.string().min(1).max(120),
  sessions: z.array(Session).max(7),
});

const Plan = z.object({
  title: z.string().min(1).max(160),
  goal: z.string().min(1).max(280),
  weeks: z.array(Week).min(1).max(16),
  weeklyVolumeNotes: z.string().max(500).optional(),
});

const Output = z.object({
  planId: z.string(),
  artifactId: z.string(),
  plan: Plan,
});

const SYSTEM = `You are an expert evidence-based programmer. Build a training plan over the requested number of weeks toward the user's goal. Respond with ONLY a JSON object matching:

{
  "title": string,
  "goal":  string,
  "weeks": Week[],   // 1..16 entries
  "weeklyVolumeNotes": string?
}
where Week = { "index": int (1-based), "theme": string, "sessions": Session[] }
and  Session = { "day": "monday"|...|"sunday", "title": string, "durationMin": int, "focus": string, "notes"?: string }

Rules:
- Progress weekly volume / intensity sensibly; include a deload every 4-6 weeks for plans 6+ weeks long.
- Respect the user's available days; don't schedule on days they didn't list as available.
- Each session needs a focus that matches the title.`;

export const proposePlanTool = defineTool({
  name: "proposePlan",
  description:
    "Generate a multi-week training plan toward a goal. Persists the plan to the user's " +
    "library and emits a `training_plan` artifact for the chat UI.",
  input: z
    .object({
      goal: z.string().min(3).max(280),
      weeks: z.number().int().min(1).max(16),
      availableDays: z
        .array(
          z.enum([
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
          ])
        )
        .min(1)
        .max(7)
        .optional(),
      sessionsPerWeek: z.number().int().min(1).max(7).optional(),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      goal: { type: "string", description: "What the plan is aiming for." },
      weeks: { type: "integer", minimum: 1, maximum: 16 },
      availableDays: {
        type: "array",
        items: {
          type: "string",
          enum: [
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
          ],
        },
      },
      sessionsPerWeek: { type: "integer", minimum: 1, maximum: 7 },
    },
    required: ["goal", "weeks"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    ctx.emit.thinking({
      id: "plan/draft",
      label: `Drafting ${args.weeks}-week plan`,
      status: "running",
    });

    const completion = await ctx.llm.chat({
      model: DEFAULT_MODELS.primary,
      messages: [
        { role: "system", content: SYSTEM },
        {
          role: "user",
          content: JSON.stringify({
            goal: args.goal,
            weeks: args.weeks,
            availableDays: args.availableDays ?? null,
            sessionsPerWeek: args.sessionsPerWeek ?? null,
          }),
        },
      ],
      temperature: 0.3,
      maxTokens: 4000,
    });

    const plan = parsePlan(completion.content);

    const planId = crypto.randomUUID();
    const now = Date.now();
    await ctx.db.insert(plans).values({
      id: planId,
      firebaseUid: ctx.uid,
      title: plan.title,
      goal: plan.goal,
      weeks: args.weeks,
      payloadJSON: JSON.stringify(plan),
      createdAt: now,
    });

    const artifactId = `plan/${planId}`;
    ctx.emit.artifact({
      id: artifactId,
      type: "training_plan",
      version: 1,
      payload: { planId, ...plan },
    });

    ctx.emit.thinking({
      id: "plan/draft",
      label: `Drafting ${args.weeks}-week plan`,
      status: "done",
    });

    return { planId, artifactId, plan };
  },
});

function parsePlan(raw: string): z.infer<typeof Plan> {
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
  const check = Plan.safeParse(parsed);
  if (!check.success) {
    throw new Error(
      `plan failed schema: ${check.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ")}`
    );
  }
  return check.data;
}
