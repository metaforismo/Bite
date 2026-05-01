import { Hono } from "hono";
import type { AppBindings } from "../types";

/**
 * GET /v1/health
 *
 * Returns the authenticated user's id. Mounted under the auth middleware,
 * so a 401 is returned automatically when no valid token is present.
 */
const health = new Hono<AppBindings>();

health.get("/health", (c) => {
  return c.json({ ok: true, uid: c.get("uid") });
});

export default health;
