import { describe, it, expect, beforeAll, beforeEach, afterEach } from "vitest";
import { env } from "cloudflare:test";
import { app } from "../src/index";
import { __setTestVerifier } from "../src/middleware/auth";
import { LLMRouter, DEFAULT_MODELS } from "../src/llm/router";

/**
 * Tests use `@cloudflare/vitest-pool-workers` to run against a real Worker
 * runtime with bindings declared in `wrangler.toml`. We swap the Firebase
 * verifier with a stub so we don't need real credentials.
 */

beforeAll(async () => {
  const testEnv = env as unknown as { DB: D1Database };
  await testEnv.DB.exec(
    "CREATE TABLE IF NOT EXISTS request_log (id integer PRIMARY KEY AUTOINCREMENT NOT NULL, firebase_uid text, path text NOT NULL, method text NOT NULL, status integer NOT NULL, latency_ms integer NOT NULL, created_at integer NOT NULL);"
  );
});

describe("/v1/health", () => {
  beforeEach(() => {
    __setTestVerifier(null);
  });
  afterEach(() => {
    __setTestVerifier(null);
  });

  it("returns 401 without a token", async () => {
    const res = await app.fetch(
      new Request("https://bite.test/v1/health"),
      env as unknown as Record<string, unknown>
    );
    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe("unauthorized");
  });

  it("returns ok + uid with a (mocked) valid token", async () => {
    __setTestVerifier(async (_token: string) => ({
      uid: "test-uid",
      email: "test@example.com",
    }));

    const res = await app.fetch(
      new Request("https://bite.test/v1/health", {
        headers: { Authorization: "Bearer fake-token" },
      }),
      env as unknown as Record<string, unknown>
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; uid: string };
    expect(body).toEqual({ ok: true, uid: "test-uid" });
  });

  it("returns 401 when the verifier rejects", async () => {
    __setTestVerifier(async () => {
      throw new Error("invalid signature");
    });

    const res = await app.fetch(
      new Request("https://bite.test/v1/health", {
        headers: { Authorization: "Bearer bogus" },
      }),
      env as unknown as Record<string, unknown>
    );
    expect(res.status).toBe(401);
  });
});

describe("LLMRouter.routeFor", () => {
  it("returns the cheap model when cheap=true", () => {
    expect(LLMRouter.routeFor({ cheap: true })).toBe(DEFAULT_MODELS.cheap);
  });

  it("returns the vision model when vision=true", () => {
    expect(LLMRouter.routeFor({ vision: true })).toBe(DEFAULT_MODELS.vision);
  });

  it("prefers cheap over vision when both are set", () => {
    // Documented order: cheap > vision > primary.
    expect(LLMRouter.routeFor({ cheap: true, vision: true })).toBe(
      DEFAULT_MODELS.cheap
    );
  });

  it("returns the primary model when no flags are set", () => {
    expect(LLMRouter.routeFor({})).toBe(DEFAULT_MODELS.primary);
  });

  it("respects an explicit model override", () => {
    expect(
      LLMRouter.routeFor({ model: DEFAULT_MODELS.mid, cheap: true })
    ).toBe(DEFAULT_MODELS.mid);
  });
});
