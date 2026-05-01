import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

/**
 * Vitest configuration that runs tests inside the Workers runtime so they
 * see real bindings (DB, FILES, VECTOR_INDEX_*) plus our env vars/secrets.
 *
 * Secrets (FIREBASE_*, OPENROUTER_API_KEY, FILE_ENCRYPTION_MASTER_KEY) are
 * not normally available in tests — the auth middleware uses the
 * `__setTestVerifier` hook so tests don't need real Firebase credentials.
 */
export default defineWorkersConfig({
  test: {
    globals: true,
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.test.toml" },
        miniflare: {
          // Provide non-empty strings for required secrets so the worker can
          // boot in test mode. These values are NEVER used because the
          // Firebase verifier is stubbed in tests.
          bindings: {
            OPENROUTER_API_KEY: "test-openrouter-key",
            FIREBASE_PROJECT_ID: "bite-test",
            FIREBASE_CLIENT_EMAIL: "test@bite-test.iam.gserviceaccount.com",
            FIREBASE_PRIVATE_KEY: "test-private-key",
            // 32 zero bytes hex-encoded (64 chars).
            FILE_ENCRYPTION_MASTER_KEY:
              "0000000000000000000000000000000000000000000000000000000000000000",
          },
        },
      },
    },
  },
});
