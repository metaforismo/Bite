import { and, eq, gte, lt } from "drizzle-orm";
import { z } from "zod";
import { cycleEntries } from "../db/schema";
import { defineTool } from "./types";

const Output = z.object({
  start: z.string(),
  end: z.string(),
  entries: z.array(
    z.object({
      date: z.string(),
      flowLevel: z.number().int(),
      symptoms: z.array(z.string()),
      source: z.string(),
    })
  ),
  inferredPhase: z
    .object({
      phase: z.enum(["menstrual", "follicular", "ovulation", "luteal"]),
      cycleDay: z.number().int(),
      cycleLength: z.number().int(),
      isLowConfidence: z.boolean(),
    })
    .nullable(),
});

export const getCycleDataTool = defineTool({
  name: "getCycleData",
  description:
    "Return menstrual cycle entries in [start, end) plus a server-inferred " +
    "phase estimate based on the most recent period start. Dates are inclusive " +
    "of start, exclusive of end (YYYY-MM-DD).",
  input: z.object({
    start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD"),
    end: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD"),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      start: { type: "string", description: "YYYY-MM-DD inclusive" },
      end: { type: "string", description: "YYYY-MM-DD exclusive" },
    },
    required: ["start", "end"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const startMs = isoToUtcMs(args.start);
    const endMs = isoToUtcMs(args.end);

    const rows = await ctx.db
      .select()
      .from(cycleEntries)
      .where(
        and(
          eq(cycleEntries.firebaseUid, ctx.uid),
          gte(cycleEntries.date, startMs),
          lt(cycleEntries.date, endMs)
        )
      );

    const entries = rows
      .map((r) => ({
        date: msToIso(r.date),
        flowLevel: r.flowLevel,
        symptoms: safeParseStrings(r.symptomsJSON),
        source: r.source,
        rawDate: r.date,
      }))
      .sort((a, b) => a.rawDate - b.rawDate);

    const inferredPhase = inferPhase(entries.map((e) => ({ date: e.rawDate, flowLevel: e.flowLevel })));

    return {
      start: args.start,
      end: args.end,
      entries: entries.map(({ rawDate: _r, ...rest }) => rest),
      inferredPhase,
    };
  },
});

function safeParseStrings(s: string): string[] {
  try {
    const v = JSON.parse(s);
    return Array.isArray(v) ? v.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

function isoToUtcMs(iso: string): number {
  const [y, m, d] = iso.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}

function msToIso(ms: number): string {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function pad(n: number): string { return n < 10 ? `0${n}` : `${n}`; }

interface PhaseInput { date: number; flowLevel: number; }

function inferPhase(entries: PhaseInput[]): {
  phase: "menstrual" | "follicular" | "ovulation" | "luteal";
  cycleDay: number;
  cycleLength: number;
  isLowConfidence: boolean;
} | null {
  const starts = periodStarts(entries);
  if (starts.length === 0) return null;
  const lastStart = starts[starts.length - 1];
  const length = inferCycleLength(starts);
  const today = startOfDayMs(Date.now());
  const days = Math.max(0, Math.floor((today - lastStart) / (24 * 60 * 60 * 1000)));
  const cycleDay = (days % length) + 1;
  let phase: "menstrual" | "follicular" | "ovulation" | "luteal";
  if (cycleDay <= 5) phase = "menstrual";
  else if (cycleDay <= length / 2 - 2) phase = "follicular";
  else if (cycleDay <= length / 2 + 1) phase = "ovulation";
  else phase = "luteal";
  return { phase, cycleDay, cycleLength: length, isLowConfidence: starts.length < 2 };
}

function periodStarts(entries: PhaseInput[]): number[] {
  const sorted = [...entries].sort((a, b) => a.date - b.date);
  const starts: number[] = [];
  let previousHadFlow = false;
  for (const e of sorted) {
    const hasFlow = e.flowLevel > 0;
    if (hasFlow && !previousHadFlow) starts.push(e.date);
    previousHadFlow = hasFlow;
  }
  return starts;
}

function inferCycleLength(starts: number[]): number {
  if (starts.length < 2) return 28;
  const deltas: number[] = [];
  for (let i = 1; i < starts.length; i++) {
    const d = Math.round((starts[i] - starts[i - 1]) / (24 * 60 * 60 * 1000));
    if (d > 14) deltas.push(d);
  }
  if (deltas.length === 0) return 28;
  const avg = deltas.reduce((a, b) => a + b, 0) / deltas.length;
  return Math.max(21, Math.min(45, Math.round(avg)));
}

function startOfDayMs(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}
