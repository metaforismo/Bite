/**
 * User profile sync.
 *
 *   PATCH /v1/users/me   upsert the profile blob the iOS app owns
 *   GET   /v1/users/me   read it back
 *
 * The iOS app is the canonical source for the profile; the worker stores it
 * as a JSON blob so `getProfile` and the chat system prompt can personalize
 * answers (name, units, goals) without a tool round-trip.
 */
import { Hono } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { users } from "../db/schema";
import type { AppBindings } from "../types";

const router = new Hono<AppBindings>();

const PatchBody = z
  .object({
    profile: z.record(z.unknown()),
  })
  .strict();

router.patch("/users/me", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);

  const parsed = PatchBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) {
    return c.json({ error: "invalid_body", issues: parsed.error.issues }, 400);
  }

  const now = Date.now();
  const profileJSON = JSON.stringify(parsed.data.profile);
  const db = drizzle(c.env.DB);
  await db
    .insert(users)
    .values({
      firebaseUid: uid,
      createdAt: now,
      profileJSON,
      profileUpdatedAt: now,
    })
    .onConflictDoUpdate({
      target: users.firebaseUid,
      set: { profileJSON, profileUpdatedAt: now },
    });

  return c.json({ ok: true, profileUpdatedAt: now });
});

router.get("/users/me", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);

  const db = drizzle(c.env.DB);
  const row = (
    await db.select().from(users).where(eq(users.firebaseUid, uid)).limit(1)
  )[0];
  if (!row?.profileJSON) {
    return c.json({ exists: false, profile: null });
  }
  let profile: unknown = null;
  try {
    profile = JSON.parse(row.profileJSON);
  } catch {
    profile = null;
  }
  return c.json({
    exists: profile !== null,
    profile,
    profileUpdatedAt: row.profileUpdatedAt,
  });
});

export default router;
