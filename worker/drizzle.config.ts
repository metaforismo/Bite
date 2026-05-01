import type { Config } from "drizzle-kit";

export default {
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "sqlite",
  driver: "d1-http",
  // The D1 driver expects credentials at runtime via env vars when running
  // drizzle-kit against a remote D1; for local generation only `schema` and
  // `out` are required. We rely on `wrangler d1 migrations apply` for actual
  // migration execution against the bound database.
  verbose: true,
  strict: true,
} satisfies Config;
