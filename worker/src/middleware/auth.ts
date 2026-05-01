import type { MiddlewareHandler } from "hono";
import type { AppBindings, Env } from "../types";

/**
 * Firebase JWT verification middleware.
 *
 * NOTE: `firebase-admin` requires Node compat in Cloudflare Workers — make
 * sure `compatibility_flags = ["nodejs_compat"]` is set in `wrangler.toml`.
 *
 * The admin SDK is initialized lazily on first request (per isolate) and
 * cached on `globalThis` so subsequent requests reuse the same `App`. We
 * import the admin modules dynamically to avoid forcing the cold-start cost
 * for unauthenticated routes.
 */

interface CachedAdmin {
  // Opaque handle returned by initializeApp; we only re-use it via getAuth().
  app: unknown;
  // Function to verify an ID token. Returns the decoded token claims.
  verifyIdToken: (idToken: string) => Promise<DecodedIdToken>;
}

interface DecodedIdToken {
  uid: string;
  email?: string;
  // ...other claims; we only consume uid + email here.
  [key: string]: unknown;
}

declare global {
  // eslint-disable-next-line no-var
  var __biteFirebaseAdmin: CachedAdmin | undefined;
}

async function getAdmin(env: Env): Promise<CachedAdmin> {
  if (globalThis.__biteFirebaseAdmin) return globalThis.__biteFirebaseAdmin;

  // Dynamic imports — `firebase-admin` is heavy and Node-flavored.
  const appMod = await import("firebase-admin/app");
  const authMod = await import("firebase-admin/auth");

  // Firebase secrets store the private key with literal "\n" sequences when
  // injected via `wrangler secret put` from a single-line value. Normalize.
  const privateKey = env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");

  let app: unknown;
  const existing = appMod.getApps();
  if (existing.length > 0) {
    app = existing[0];
  } else {
    app = appMod.initializeApp({
      credential: appMod.cert({
        projectId: env.FIREBASE_PROJECT_ID,
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
        privateKey,
      }),
    });
  }

  const auth = authMod.getAuth(app as Parameters<typeof authMod.getAuth>[0]);

  const cached: CachedAdmin = {
    app,
    verifyIdToken: async (idToken: string) => {
      const decoded = await auth.verifyIdToken(idToken);
      return decoded as DecodedIdToken;
    },
  };
  globalThis.__biteFirebaseAdmin = cached;
  return cached;
}

/**
 * Hook for tests to inject a fake verifier without touching firebase-admin.
 * When set, `firebaseAuth()` will use this in place of the cached admin.
 */
let testVerifier: ((idToken: string) => Promise<DecodedIdToken>) | null = null;
export function __setTestVerifier(
  fn: ((idToken: string) => Promise<DecodedIdToken>) | null
): void {
  testVerifier = fn;
}

export function firebaseAuth(): MiddlewareHandler<AppBindings> {
  return async (c, next) => {
    // Hono's `c.req.header()` is case-insensitive.
    const authHeader = c.req.header("authorization");
    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const idToken = authHeader.slice("bearer ".length).trim();
    if (!idToken) {
      return c.json({ error: "unauthorized" }, 401);
    }

    try {
      const verify =
        testVerifier ?? (await getAdmin(c.env)).verifyIdToken;
      const decoded = await verify(idToken);
      c.set("uid", decoded.uid);
      c.set("email", decoded.email);
      await next();
    } catch (err) {
      console.error("[auth] verifyIdToken failed", err);
      return c.json({ error: "unauthorized" }, 401);
    }
  };
}
