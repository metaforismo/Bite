# bite-worker

Cloudflare Worker backend for the Bite AI health agent.

Stack:

- Hono + TypeScript
- Cloudflare D1 (relational) via Drizzle ORM
- Cloudflare R2 (encrypted file uploads)
- Cloudflare Vectorize (memory + file embeddings)
- Firebase Admin (JWT verification)
- OpenRouter (LLM gateway, accessed via the OpenAI SDK)

## Install

```sh
pnpm install
```

## Set up D1

Create the database, then paste the returned `database_id` into `wrangler.toml` (the `YOUR_D1_ID_HERE` placeholder):

```sh
wrangler d1 create bite_db
```

Apply the initial migration locally and remotely:

```sh
pnpm db:migrate:local
pnpm db:migrate:remote
```

When you change `src/db/schema.ts`, run:

```sh
pnpm db:generate
```

…then commit the new file in `drizzle/` and apply it.

## Set secrets

```sh
wrangler secret put OPENROUTER_API_KEY
wrangler secret put FIREBASE_PROJECT_ID
wrangler secret put FIREBASE_CLIENT_EMAIL
wrangler secret put FIREBASE_PRIVATE_KEY            # paste the PEM with \n escapes
wrangler secret put FILE_ENCRYPTION_MASTER_KEY      # `openssl rand -hex 32`
```

For local development you can put the same names in a `.dev.vars` file (gitignored).

## Run locally

```sh
pnpm dev
```

Worker listens on `http://localhost:8787`. Health check (requires a valid Firebase ID token):

```sh
curl -H "Authorization: Bearer $FIREBASE_ID_TOKEN" http://localhost:8787/v1/health
```

## Test

```sh
pnpm test
```

Tests run in the real Workers runtime via `@cloudflare/vitest-pool-workers`.

## Typecheck

```sh
pnpm typecheck
```

## Deploy

```sh
pnpm deploy
```

## Routes

- `GET  /v1/health` — auth probe, returns `{ ok, uid }`
- `POST /v1/chat/threads` — create a chat thread
- `GET  /v1/chat/threads` — list threads (50 most recent)
- `GET  /v1/chat/threads/:id` — thread + last 100 messages

All `/v1/*` routes require a Firebase ID token in the `Authorization: Bearer …` header.

## Notes

- `firebase-admin` requires `nodejs_compat`, already set in `wrangler.toml`.
- File uploads are encrypted with a per-user AES-256-GCM key derived from `FILE_ENCRYPTION_MASTER_KEY` via HKDF-SHA256 (`src/encryption.ts`). Master key compromise rotates all users; per-user key compromise affects only that user.
- The LLM router (`src/llm/router.ts`) maps `cheap`/`vision` flags to OpenRouter model ids; pass `model:` to override explicitly.
