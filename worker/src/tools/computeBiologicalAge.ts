import { and, desc, eq, gte } from "drizzle-orm";
import { z } from "zod";
import {
  biomarkers as biomarkersTbl,
  bioAgeSnapshots,
  drinks,
  foodEntries,
  strengthSessions,
} from "../db/schema";
import { defineTool } from "./types";

const Driver = z.object({
  id: z.string(),
  label: z.string(),
  deltaYears: z.number(),
});

const Breakdown = z.object({
  sleep: z.array(Driver),
  activity: z.array(Driver),
  fitness: z.array(Driver),
  lifestyle: z.array(Driver),
  blood: z.array(Driver),
});

const Output = z.object({
  artifactId: z.string(),
  chronologicalAge: z.number().int(),
  biologicalAge: z.number(),
  confidence: z.number().min(0).max(1),
  breakdown: Breakdown,
  computedAt: z.number(),
  cached: z.boolean(),
});

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

export const computeBiologicalAgeTool = defineTool({
  name: "computeBiologicalAge",
  description:
    "Compute (or return the cached) biological-age estimate for the user. " +
    "Reads recent biomarkers + iOS health snapshot + lifestyle data, applies " +
    "a deterministic scoring rubric, persists a `bio_age_snapshots` row, and " +
    "emits a `confidence_dial` artifact.",
  input: z.object({
    refresh: z.boolean().default(false),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      refresh: { type: "boolean", description: "Force recompute even if a snapshot is fresh" },
    },
    additionalProperties: false,
  },
  async run(args, ctx) {
    const now = Date.now();
    const fresh = await ctx.db
      .select()
      .from(bioAgeSnapshots)
      .where(eq(bioAgeSnapshots.firebaseUid, ctx.uid))
      .orderBy(desc(bioAgeSnapshots.computedAt))
      .limit(1);

    if (!args.refresh && fresh.length > 0 && now - fresh[0].computedAt < CACHE_TTL_MS) {
      const cached = fresh[0];
      const breakdown = safeParseBreakdown(cached.breakdownJSON);
      const artifactId = crypto.randomUUID();
      ctx.emit.artifact({
        id: artifactId,
        type: "confidence_dial",
        payload: dialPayload(cached.biologicalAge, cached.chronologicalAge, cached.confidence),
        version: 1,
      });
      return {
        artifactId,
        chronologicalAge: cached.chronologicalAge,
        biologicalAge: cached.biologicalAge,
        confidence: cached.confidence,
        breakdown,
        computedAt: cached.computedAt,
        cached: true,
      };
    }

    // Source data ----------------------------------------------------------
    const profile = (() => {
      try { return JSON.parse((ctx.healthSnapshot as { profileJSON?: string } | undefined)?.profileJSON ?? "{}"); }
      catch { return {}; }
    })();
    const chronologicalAge: number = Number(profile?.age ?? 30);
    const snap = ctx.healthSnapshot ?? {};

    const drivers = await collectDrivers(ctx, snap);

    const totalDelta = sumDrivers(drivers);
    const biologicalAge = Math.max(15, chronologicalAge + totalDelta);
    const confidence = computeConfidence(drivers, snap);

    const id = crypto.randomUUID();
    const breakdownJson = JSON.stringify(drivers);
    await ctx.db.insert(bioAgeSnapshots).values({
      id,
      firebaseUid: ctx.uid,
      computedAt: now,
      chronologicalAge,
      biologicalAge,
      confidence,
      breakdownJSON: breakdownJson,
    });

    const artifactId = crypto.randomUUID();
    ctx.emit.artifact({
      id: artifactId,
      type: "confidence_dial",
      payload: dialPayload(biologicalAge, chronologicalAge, confidence),
      version: 1,
    });

    return {
      artifactId,
      chronologicalAge,
      biologicalAge,
      confidence,
      breakdown: drivers,
      computedAt: now,
      cached: false,
    };
  },
});

interface BreakdownShape {
  sleep: Driver[];
  activity: Driver[];
  fitness: Driver[];
  lifestyle: Driver[];
  blood: Driver[];
}
interface Driver { id: string; label: string; deltaYears: number; }

function sumDrivers(b: BreakdownShape): number {
  return [
    ...b.sleep, ...b.activity, ...b.fitness, ...b.lifestyle, ...b.blood,
  ].reduce((acc, d) => acc + d.deltaYears, 0);
}

async function collectDrivers(ctx: import("./types").ToolContext, snap: import("./types").HealthSnapshot): Promise<BreakdownShape> {
  const out: BreakdownShape = { sleep: [], activity: [], fitness: [], lifestyle: [], blood: [] };

  // Sleep ----------------------------------------------------------------
  if (typeof snap.sleepHours === "number") {
    const dev = snap.sleepHours - 7.5;
    out.sleep.push(driver("Sleep duration", dev > 0 ? -0.4 : 0.6 * Math.min(2, Math.abs(dev))));
  }
  if (typeof snap.hrv === "number") {
    const baseline = 50;
    out.sleep.push(driver("HRV", -((snap.hrv - baseline) / 40)));
  }

  // Activity -------------------------------------------------------------
  if (typeof snap.steps === "number") {
    const stepsDelta = (snap.steps - 7500) / 5000;
    out.activity.push(driver("Daily steps", -stepsDelta));
  }
  if (Array.isArray(snap.workouts) && snap.workouts.length > 0) {
    out.activity.push(driver("Workouts logged this week", -Math.min(1.5, snap.workouts.length * 0.25)));
  }

  // Fitness --------------------------------------------------------------
  if (typeof snap.vo2Max === "number") {
    out.fitness.push(driver("VO₂ max", -((snap.vo2Max - 35) / 8)));
  }
  const ninetyDaysAgo = Date.now() - 90 * 24 * 60 * 60 * 1000;
  const recentSessions = await ctx.db
    .select({ id: strengthSessions.id })
    .from(strengthSessions)
    .where(and(eq(strengthSessions.firebaseUid, ctx.uid), gte(strengthSessions.startedAt, ninetyDaysAgo)));
  if (recentSessions.length > 0) {
    out.fitness.push(driver("Strength training consistency", -Math.min(1.2, recentSessions.length * 0.05)));
  }

  // Lifestyle ------------------------------------------------------------
  const recentDrinks = await ctx.db
    .select()
    .from(drinks)
    .where(and(eq(drinks.firebaseUid, ctx.uid), gte(drinks.timestamp, ninetyDaysAgo)));
  const caffDays = new Set(recentDrinks.filter((d) => d.kind === "caffeine").map((d) => d.dayStart)).size;
  if (caffDays > 0) {
    const avgPerDay = recentDrinks.filter((d) => d.kind === "caffeine").reduce((a, d) => a + (d.caffeineMg ?? 0), 0) / Math.max(1, caffDays);
    if (avgPerDay > 400) {
      out.lifestyle.push(driver("High caffeine intake", 0.4));
    }
  }
  const recentMeals = await ctx.db
    .select({ kcal: foodEntries.kcal })
    .from(foodEntries)
    .where(and(eq(foodEntries.firebaseUid, ctx.uid), gte(foodEntries.dayStart, ninetyDaysAgo)));
  if (recentMeals.length > 30) {
    out.lifestyle.push(driver("Consistent food logging", -0.2));
  }

  // Blood ----------------------------------------------------------------
  const recentBio = await ctx.db
    .select()
    .from(biomarkersTbl)
    .where(and(eq(biomarkersTbl.firebaseUid, ctx.uid), gte(biomarkersTbl.takenAt, ninetyDaysAgo)));
  for (const b of recentBio.slice(0, 8)) {
    if (b.refLow != null && b.refHigh != null) {
      const inRange = b.value >= b.refLow && b.value <= b.refHigh;
      out.blood.push(driver(b.name, inRange ? -0.2 : 0.4));
    }
  }

  return out;
}

function driver(label: string, deltaYears: number): Driver {
  return { id: crypto.randomUUID(), label, deltaYears: round(deltaYears, 2) };
}

function round(n: number, digits: number): number {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

function computeConfidence(b: BreakdownShape, snap: import("./types").HealthSnapshot): number {
  let signals = 0;
  if (typeof snap.sleepHours === "number") signals++;
  if (typeof snap.hrv === "number") signals++;
  if (typeof snap.steps === "number") signals++;
  if (typeof snap.vo2Max === "number") signals++;
  if (b.blood.length > 0) signals += Math.min(2, b.blood.length / 4);
  if (b.fitness.length > 0) signals++;
  return Math.min(0.95, 0.35 + signals * 0.08);
}

function dialPayload(bioAge: number, chronoAge: number, confidence: number): Record<string, unknown> {
  return {
    title: "Biological age",
    value: round(bioAge, 1),
    target: chronoAge,
    unit: "years",
    confidence,
    drivers: [],
  };
}

function safeParseBreakdown(s: string): BreakdownShape {
  try {
    const v = JSON.parse(s);
    return {
      sleep: Array.isArray(v.sleep) ? v.sleep : [],
      activity: Array.isArray(v.activity) ? v.activity : [],
      fitness: Array.isArray(v.fitness) ? v.fitness : [],
      lifestyle: Array.isArray(v.lifestyle) ? v.lifestyle : [],
      blood: Array.isArray(v.blood) ? v.blood : [],
    };
  } catch {
    return { sleep: [], activity: [], fitness: [], lifestyle: [], blood: [] };
  }
}
