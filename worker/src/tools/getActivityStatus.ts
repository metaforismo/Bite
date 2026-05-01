import { desc, eq } from "drizzle-orm";
import { z } from "zod";
import { activityStatus } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  kind: z.enum(["active", "sick", "injured", "on_break"]),
  startedAt: z.number(),
  daysActive: z.number().int().nonnegative(),
  note: z.string().nullable(),
});

export const getActivityStatusTool = defineTool({
  name: "getActivityStatus",
  description:
    "Return the user's current activity status (most recent row) along with " +
    "how many days they've been in this state.",
  input: z.object({}).strict(),
  output: Output,
  parameters: { type: "object", properties: {}, additionalProperties: false },
  async run(_args, ctx) {
    const rows = await ctx.db
      .select()
      .from(activityStatus)
      .where(eq(activityStatus.firebaseUid, ctx.uid))
      .orderBy(desc(activityStatus.startedAt))
      .limit(1);
    if (rows.length === 0) {
      return {
        kind: "active" as const,
        startedAt: Date.now(),
        daysActive: 0,
        note: null,
      };
    }
    const r = rows[0];
    const daysActive = Math.max(
      0,
      Math.floor((Date.now() - r.startedAt) / (24 * 60 * 60 * 1000))
    );
    return {
      kind: r.kind as "active" | "sick" | "injured" | "on_break",
      startedAt: r.startedAt,
      daysActive,
      note: r.note,
    };
  },
});
