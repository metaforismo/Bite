import { z } from "zod";
import { checkIns } from "../db/schema";
import { defineTool } from "./types";

/**
 * Schedule a recurring check-in (e.g. "ask me about sleep at 10pm daily").
 *
 * Returns the row id plus an `alarm` payload the iOS client uses to register
 * an AlarmKit alarm locally. The cadence string is parsed lightly to compute
 * the first fire time; complex schedules can be expanded by the client.
 */

const cadenceRegex = /^(daily|weekly:(monday|tuesday|wednesday|thursday|friday|saturday|sunday))@(\d{2}):(\d{2})$/;

const Output = z.object({
  id: z.string(),
  prompt: z.string(),
  cadence: z.string(),
  nextFireAt: z.number(),
  alarm: z.object({
    id: z.string(),
    prompt: z.string(),
    cadence: z.string(),
    nextFireAt: z.number(),
  }),
});

export const scheduleCheckInTool = defineTool({
  name: "scheduleCheckIn",
  description:
    "Schedule a recurring check-in for this user. The iOS client will turn the returned " +
    "`alarm` payload into a local AlarmKit alarm. Cadence is `daily@HH:MM` or " +
    "`weekly:<day>@HH:MM` (lowercase day, 24h time).",
  input: z
    .object({
      prompt: z.string().min(3).max(200),
      cadence: z.string().regex(cadenceRegex, {
        message: "expected daily@HH:MM or weekly:<day>@HH:MM",
      }),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      prompt: {
        type: "string",
        description: "What the check-in should ask the user.",
      },
      cadence: {
        type: "string",
        description:
          "daily@HH:MM or weekly:<day>@HH:MM (24h time, lowercase day).",
        pattern:
          "^(daily|weekly:(monday|tuesday|wednesday|thursday|friday|saturday|sunday))@(\\d{2}):(\\d{2})$",
      },
    },
    required: ["prompt", "cadence"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const id = crypto.randomUUID();
    const nextFireAt = computeNextFire(args.cadence, Date.now());
    await ctx.db.insert(checkIns).values({
      id,
      firebaseUid: ctx.uid,
      prompt: args.prompt,
      cadence: args.cadence,
      nextFireAt,
    });
    return {
      id,
      prompt: args.prompt,
      cadence: args.cadence,
      nextFireAt,
      alarm: {
        id,
        prompt: args.prompt,
        cadence: args.cadence,
        nextFireAt,
      },
    };
  },
});

const DAY_INDEX: Record<string, number> = {
  sunday: 0,
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
  saturday: 6,
};

/**
 * Compute the next fire time (ms epoch, UTC) for a cadence string. We treat
 * HH:MM as UTC for now — the client converts to the user's local clock when
 * registering the alarm.
 */
export function computeNextFire(cadence: string, nowMs: number): number {
  const m = cadence.match(cadenceRegex);
  if (!m) throw new Error(`invalid cadence: ${cadence}`);
  const [, head, weekday, hh, mm] = m;
  const hour = Number(hh);
  const min = Number(mm);
  const now = new Date(nowMs);

  if (head === "daily") {
    const candidate = Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate(),
      hour,
      min,
      0,
      0
    );
    return candidate > nowMs ? candidate : candidate + 24 * 60 * 60 * 1000;
  }

  if (!weekday) throw new Error(`invalid cadence: ${cadence}`);
  const targetDow = DAY_INDEX[weekday];
  if (targetDow == null) throw new Error(`invalid weekday: ${weekday}`);
  const today = now.getUTCDay();
  let daysAhead = (targetDow - today + 7) % 7;
  let candidate = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + daysAhead,
    hour,
    min,
    0,
    0
  );
  if (candidate <= nowMs) {
    candidate += 7 * 24 * 60 * 60 * 1000;
  }
  return candidate;
}
