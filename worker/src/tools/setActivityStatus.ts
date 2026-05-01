import { z } from "zod";
import { activityStatus } from "../db/schema";
import { defineTool } from "./types";

const KIND = ["active", "sick", "injured", "on_break"] as const;

const Output = z.object({
  id: z.string(),
  kind: z.enum(KIND),
  startedAt: z.number(),
  note: z.string().nullable(),
});

export const setActivityStatusTool = defineTool({
  name: "setActivityStatus",
  description:
    "Record the user's current activity status. Append-only — the latest row " +
    "wins. Use this whenever the user says they're getting sick, injured, " +
    "taking a break, or returning to active training.",
  input: z.object({
    kind: z.enum(KIND),
    startedAt: z.number().optional(),
    note: z.string().max(280).optional(),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      kind: { type: "string", enum: ["active", "sick", "injured", "on_break"] },
      startedAt: {
        type: "number",
        description: "Unix epoch ms when the status started; defaults to now",
      },
      note: { type: "string", description: "optional context, e.g. 'Strained calf'" },
    },
    required: ["kind"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const id = crypto.randomUUID();
    const now = Date.now();
    const startedAt = args.startedAt ?? now;
    await ctx.db.insert(activityStatus).values({
      id,
      firebaseUid: ctx.uid,
      kind: args.kind,
      startedAt,
      note: args.note ?? null,
      createdAt: now,
    });
    return {
      id,
      kind: args.kind,
      startedAt,
      note: args.note ?? null,
    };
  },
});
