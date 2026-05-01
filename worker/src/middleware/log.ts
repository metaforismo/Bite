import type { MiddlewareHandler } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { requestLog } from "../db/schema";
import type { AppBindings } from "../types";

/**
 * Request-logging middleware.
 *
 * Records every request into `request_log` with path, method, response
 * status, and latency. The insert is fire-and-forget via `c.executionCtx
 * .waitUntil` so logging never blocks the response.
 */
export function requestLogger(): MiddlewareHandler<AppBindings> {
  return async (c, next) => {
    const startedAt = Date.now();
    c.set("requestStartMs", startedAt);

    await next();

    const latencyMs = Date.now() - startedAt;
    const status = c.res.status;
    const uid = c.get("uid") ?? null;
    const path = new URL(c.req.url).pathname;
    const method = c.req.method;

    const insert = async () => {
      try {
        const db = drizzle(c.env.DB);
        await db.insert(requestLog).values({
          firebaseUid: uid,
          path,
          method,
          status,
          latencyMs,
          createdAt: Date.now(),
        });
      } catch (err) {
        // Don't let logging failures surface to the user.
        console.error("[requestLogger] insert failed", err);
      }
    };

    try {
      c.executionCtx.waitUntil(insert());
    } catch {
      // executionCtx may not be available in some test contexts.
      await insert();
    }
  };
}
