/**
 * Shared environment + Hono context types for the Bite worker.
 *
 * `Env` mirrors the bindings declared in `wrangler.toml`. Whenever you add a
 * new binding or var/secret in wrangler, add it here so it is type-checked
 * across the worker.
 */
export interface Env {
  // Cloudflare bindings
  DB: D1Database;
  FILES: R2Bucket;
  VECTOR_INDEX_MEMORIES: VectorizeIndex;
  VECTOR_INDEX_FILES: VectorizeIndex;

  // Vars (public, set in wrangler.toml [vars])
  OPENROUTER_BASE_URL: string;

  // Secrets (set via `wrangler secret put`)
  OPENROUTER_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
  FILE_ENCRYPTION_MASTER_KEY: string;
}

/**
 * Hono `Variables` populated by middleware.
 *
 * `uid` and `email` are set by `firebaseAuth()` and are therefore only
 * present on `/v1/*` routes. The request logger runs on all routes (including
 * unauthenticated ones), so it must treat them as possibly-undefined.
 */
export interface Variables {
  uid?: string;
  email?: string;
  requestStartMs?: number;
}

export interface AppBindings {
  Bindings: Env;
  Variables: Variables;
}
