/**
 * V2 read-only endpoints — Today snapshot, Bio Age cache, Journal insights,
 * Drinks summary. These exist alongside the chat-tool surface so iOS can
 * render Today/Biology/Journal directly without going through a full chat
 * turn for every refresh.
 */

import { Hono } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { and, desc, eq, gte, lt } from "drizzle-orm";
import {
  activityStatus,
  bioAgeSnapshots,
  cycleEntries,
  drinks,
  foodEntries,
  journalTags,
} from "../db/schema";
import type { AppBindings } from "../types";

const v2 = new Hono<AppBindings>();

/**
 * GET /v1/today — overnight-baked daily snapshot the iOS Today view + the
 * widget extension share. For now, computed on demand from D1; the nightly
 * cron worker can later pre-compute and cache it.
 */
v2.get("/today", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const db = drizzle(c.env.DB);

  const day = startOfDayMs(Date.now());
  const next = day + 86400000;

  const meals = await db
    .select()
    .from(foodEntries)
    .where(
      and(
        eq(foodEntries.firebaseUid, uid),
        gte(foodEntries.dayStart, day),
        lt(foodEntries.dayStart, next)
      )
    );

  const consumedKcal = meals.reduce((acc, m) => acc + (m.kcal ?? 0), 0);
  const protein = meals.reduce((acc, m) => acc + (m.protein ?? 0), 0);
  const carbs = meals.reduce((acc, m) => acc + (m.carbs ?? 0), 0);
  const fat = meals.reduce((acc, m) => acc + (m.fat ?? 0), 0);
  const fiber = meals.reduce((acc, m) => acc + (m.fiber ?? 0), 0);

  const todayDrinks = await db
    .select()
    .from(drinks)
    .where(
      and(
        eq(drinks.firebaseUid, uid),
        gte(drinks.timestamp, day),
        lt(drinks.timestamp, next)
      )
    );
  const hydrationMl = todayDrinks
    .filter((d) => d.kind === "water")
    .reduce((acc, d) => acc + (d.volumeMl ?? 0), 0);
  const caffeineMg = todayDrinks
    .filter((d) => d.kind === "caffeine")
    .reduce((acc, d) => acc + (d.caffeineMg ?? 0), 0);

  const status = await db
    .select()
    .from(activityStatus)
    .where(eq(activityStatus.firebaseUid, uid))
    .orderBy(desc(activityStatus.startedAt))
    .limit(1);

  return c.json({
    date: msToIso(day),
    consumedKcal,
    protein,
    carbs,
    fat,
    fiber,
    hydrationMl,
    caffeineMg,
    drinkCount: todayDrinks.length,
    activityStatus: status[0]
      ? {
          kind: status[0].kind,
          startedAt: status[0].startedAt,
          daysActive: Math.max(
            0,
            Math.floor((Date.now() - status[0].startedAt) / 86400000)
          ),
        }
      : { kind: "active", startedAt: Date.now(), daysActive: 0 },
  });
});

/**
 * GET /v1/bio-age — return the most recent bio-age snapshot. Use POST
 * /v1/bio-age/refresh to force a recompute.
 */
v2.get("/bio-age", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const db = drizzle(c.env.DB);
  const rows = await db
    .select()
    .from(bioAgeSnapshots)
    .where(eq(bioAgeSnapshots.firebaseUid, uid))
    .orderBy(desc(bioAgeSnapshots.computedAt))
    .limit(1);

  if (rows.length === 0) {
    return c.json({ ready: false }, 200);
  }

  const r = rows[0];
  let breakdown: unknown = {};
  try { breakdown = JSON.parse(r.breakdownJSON); } catch { breakdown = {}; }
  return c.json({
    ready: true,
    computedAt: r.computedAt,
    chronologicalAge: r.chronologicalAge,
    biologicalAge: r.biologicalAge,
    confidence: r.confidence,
    breakdown,
  });
});

/**
 * GET /v1/journal/insights — top positive and negative habit-impact bars
 * across the requested period. Aggregates `journal_tags` rows with the same
 * Welch's t-test logic the analyzeImpactByTag tool uses.
 */
v2.get("/journal/insights", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const period = (c.req.query("period") ?? "30d") as "30d" | "60d" | "90d";
  const db = drizzle(c.env.DB);

  const days = period === "90d" ? 90 : period === "60d" ? 60 : 30;
  const sinceMs = Date.now() - days * 86400000;

  const tagRows = await db
    .select()
    .from(journalTags)
    .where(
      and(eq(journalTags.firebaseUid, uid), gte(journalTags.createdAt, sinceMs))
    );

  const meals = await db
    .select({ kcal: foodEntries.kcal, protein: foodEntries.protein, dayStart: foodEntries.dayStart })
    .from(foodEntries)
    .where(
      and(eq(foodEntries.firebaseUid, uid), gte(foodEntries.dayStart, sinceMs))
    );

  const dayKcal = new Map<number, number>();
  for (const m of meals) {
    dayKcal.set(m.dayStart, (dayKcal.get(m.dayStart) ?? 0) + (m.kcal ?? 0));
  }

  // Group days by tag and compute simple delta-percent vs. untagged baseline.
  const tagDays = new Map<string, Set<number>>();
  for (const t of tagRows) {
    if (!tagDays.has(t.tag)) tagDays.set(t.tag, new Set());
    tagDays.get(t.tag)!.add(startOfDayMs(t.createdAt));
  }

  type Bar = { tag: string; deltaPercent: number; isPositive: boolean; daysWithTag: number };
  const bars: Bar[] = [];
  for (const [tag, daysSet] of tagDays.entries()) {
    let withSum = 0, withCount = 0, withoutSum = 0, withoutCount = 0;
    for (const [day, kcal] of dayKcal.entries()) {
      if (daysSet.has(day)) { withSum += kcal; withCount++; }
      else { withoutSum += kcal; withoutCount++; }
    }
    if (withCount === 0 || withoutCount === 0) continue;
    const withAvg = withSum / withCount;
    const withoutAvg = withoutSum / withoutCount;
    if (withoutAvg === 0) continue;
    const delta = ((withAvg - withoutAvg) / withoutAvg) * 100;
    bars.push({
      tag,
      deltaPercent: Math.round(delta * 10) / 10,
      isPositive: delta >= 0,
      daysWithTag: withCount,
    });
  }

  bars.sort((a, b) => Math.abs(b.deltaPercent) - Math.abs(a.deltaPercent));
  const positive = bars.filter((b) => b.isPositive).slice(0, 6);
  const negative = bars.filter((b) => !b.isPositive).slice(0, 6);

  return c.json({ period, positive, negative });
});

/**
 * GET /v1/cycle?days=28 — read-only mirror of the most recent N days of
 * cycle entries plus a server-inferred phase (same algorithm as the
 * getCycleData tool).
 */
v2.get("/cycle", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const days = Number(c.req.query("days") ?? "28");
  const db = drizzle(c.env.DB);
  const sinceMs = startOfDayMs(Date.now() - days * 86400000);

  const rows = await db
    .select()
    .from(cycleEntries)
    .where(
      and(eq(cycleEntries.firebaseUid, uid), gte(cycleEntries.date, sinceMs))
    )
    .orderBy(desc(cycleEntries.date));

  return c.json({
    days,
    entries: rows.map((r) => ({
      date: msToIso(r.date),
      flowLevel: r.flowLevel,
      symptoms: safeParseStrings(r.symptomsJSON),
      source: r.source,
    })),
  });
});

function startOfDayMs(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

function msToIso(ms: number): string {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function pad(n: number): string { return n < 10 ? `0${n}` : `${n}`; }

function safeParseStrings(s: string): string[] {
  try {
    const v = JSON.parse(s);
    return Array.isArray(v) ? v.filter((x) => typeof x === "string") : [];
  } catch { return []; }
}

export default v2;
