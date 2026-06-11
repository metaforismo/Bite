import { Hono } from "hono";
import { cors } from "hono/cors";
import type { AppBindings } from "./types";
import { firebaseAuth } from "./middleware/auth";
import { requestLogger } from "./middleware/log";
import healthRoute from "./routes/health";
import usersRoute from "./routes/users";
import chatRoute from "./routes/chat";
import chatStreamRoute from "./routes/chat-stream";
import filesRoute from "./routes/files";
import v2Route from "./routes/v2";

/**
 * Bite worker entry point.
 *
 * Layout:
 *   /v1/*   — authenticated API surface, Firebase JWT required.
 *   /       — public: 200 with build info to keep simple uptime checks happy.
 *
 * `firebase-admin` requires the `nodejs_compat` flag, which is set in
 * `wrangler.toml`.
 */

const app = new Hono<AppBindings>();

// CORS first so preflights short-circuit before auth.
app.use(
  "*",
  cors({
    // Reflect the request origin. Tighten to an allowlist before going to
    // production with a public client.
    origin: (origin) => origin ?? "*",
    allowHeaders: ["Authorization", "Content-Type"],
    allowMethods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    credentials: true,
    maxAge: 600,
  })
);

// Request logging on every request (including unauthenticated ones).
app.use("*", requestLogger());

// Public root.
app.get("/", (c) =>
  c.json({
    service: "bite-worker",
    ok: true,
  })
);

// Authenticated API surface.
const v1 = new Hono<AppBindings>();
v1.use("*", firebaseAuth());
v1.route("/", healthRoute);
v1.route("/", usersRoute);
v1.route("/", chatRoute);
v1.route("/", chatStreamRoute);
v1.route("/", filesRoute);
v1.route("/", v2Route);
app.route("/v1", v1);

// Top-level error fallback so users never see a stack trace.
app.onError((err, c) => {
  console.error("[onError]", err);
  return c.json({ error: "internal_error" }, 500);
});

app.notFound((c) => c.json({ error: "not_found" }, 404));

export default {
  fetch: app.fetch,
};

// Re-export so tests and tools can import the constructed app directly.
export { app };
