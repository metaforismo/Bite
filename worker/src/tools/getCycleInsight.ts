import { z } from "zod";
import { defineTool } from "./types";

const Output = z.object({
  artifactId: z.string(),
  text: z.string(),
});

const SYSTEM = `You are Bite's cycle-aware coach. Given a user's current
cycle phase + day, return a 2-paragraph insight tailored to that phase:
one paragraph on physiology, one paragraph on practical guidance for today
(nutrition + training intensity). Keep tone warm, specific, and grounded.
Avoid hedging language like "might be a good idea". Never give medical
diagnoses.`;

export const getCycleInsightTool = defineTool({
  name: "getCycleInsight",
  description:
    "Generate a 2-paragraph insight for the user's current menstrual cycle " +
    "phase. Emits a `text_report` artifact and returns its id + text.",
  input: z.object({
    phase: z.enum(["menstrual", "follicular", "ovulation", "luteal"]),
    cycleDay: z.number().int().min(1).max(45),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      phase: { type: "string", enum: ["menstrual", "follicular", "ovulation", "luteal"] },
      cycleDay: { type: "integer", minimum: 1, maximum: 45 },
    },
    required: ["phase", "cycleDay"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const text = await ctx.llm.completeText({
      task: "reasoning",
      system: SYSTEM,
      user: `Cycle phase: ${args.phase}\nCycle day: ${args.cycleDay}\n\nWrite the 2-paragraph insight now.`,
      maxTokens: 360,
    });

    const artifactId = crypto.randomUUID();
    ctx.emit.artifact({
      id: artifactId,
      type: "text_report",
      payload: {
        title: titleFor(args.phase, args.cycleDay),
        body: text,
        source: "cycle_insight",
      },
      version: 1,
    });

    return { artifactId, text };
  },
});

function titleFor(phase: string, day: number): string {
  switch (phase) {
    case "menstrual": return `Day ${day} of period`;
    case "follicular": return `Follicular phase · Day ${day}`;
    case "ovulation": return `Ovulation window · Day ${day}`;
    case "luteal": return `Luteal phase · Day ${day}`;
    default: return `Cycle day ${day}`;
  }
}
