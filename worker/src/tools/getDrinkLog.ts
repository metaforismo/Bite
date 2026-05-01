import { and, eq, gte, lt } from "drizzle-orm";
import { z } from "zod";
import { drinks } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  date: z.string(),
  totalWaterMl: z.number(),
  totalCaffeineMg: z.number(),
  drinks: z.array(
    z.object({
      id: z.string(),
      kind: z.enum(["water", "caffeine"]),
      volumeMl: z.number().nullable(),
      caffeineMg: z.number().nullable(),
      label: z.string().nullable(),
      timestamp: z.number(),
    })
  ),
});

export const getDrinkLogTool = defineTool({
  name: "getDrinkLog",
  description:
    "Return every drink (water + caffeine) the user logged on a given day. " +
    "Date format: YYYY-MM-DD (UTC).",
  input: z.object({
    date: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD"),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      date: { type: "string", description: "YYYY-MM-DD (UTC)" },
    },
    required: ["date"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const dayStart = isoToUtcMs(args.date);
    const dayEnd = dayStart + 24 * 60 * 60 * 1000;
    const rows = await ctx.db
      .select()
      .from(drinks)
      .where(
        and(
          eq(drinks.firebaseUid, ctx.uid),
          gte(drinks.timestamp, dayStart),
          lt(drinks.timestamp, dayEnd)
        )
      );
    let totalWaterMl = 0;
    let totalCaffeineMg = 0;
    for (const r of rows) {
      if (r.kind === "water") totalWaterMl += r.volumeMl ?? 0;
      if (r.kind === "caffeine") totalCaffeineMg += r.caffeineMg ?? 0;
    }
    return {
      date: args.date,
      totalWaterMl,
      totalCaffeineMg,
      drinks: rows.map((r) => ({
        id: r.id,
        kind: r.kind as "water" | "caffeine",
        volumeMl: r.volumeMl,
        caffeineMg: r.caffeineMg,
        label: r.label,
        timestamp: r.timestamp,
      })),
    };
  },
});

function isoToUtcMs(iso: string): number {
  const [y, m, d] = iso.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}
