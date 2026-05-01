/**
 * File upload + analysis routes.
 *
 *   POST /v1/files/upload-url   issue a presigned R2 PUT URL + fileId
 *   POST /v1/files/:id/analyze  kick off lab parsing on an uploaded file
 *   GET  /v1/files/:id          metadata + status
 */
import { Hono } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { files, labReports } from "../db/schema";
import type { AppBindings } from "../types";
import { LLMRouter } from "../llm/router";
import { runLabAnalysis } from "../jobs/analyze";

const router = new Hono<AppBindings>();

const uploadUrlBody = z
  .object({
    mimeType: z.string().min(1),
    displayName: z.string().min(1).max(255),
    sizeBytes: z.number().int().min(1).max(50 * 1024 * 1024),
  })
  .strict();

router.post("/files/upload-url", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const parsed = uploadUrlBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) {
    return c.json({ error: "invalid_body", issues: parsed.error.issues }, 400);
  }

  const fileId = crypto.randomUUID();
  const r2Key = `users/${uid}/uploads/${fileId}`;
  const now = Date.now();

  const db = drizzle(c.env.DB);
  await db.insert(files).values({
    id: fileId,
    firebaseUid: uid,
    r2Key,
    mimeType: parsed.data.mimeType,
    sizeBytes: parsed.data.sizeBytes,
    uploadedAt: now,
  });

  // Cloudflare R2 supports presigned PUTs only via the S3-compatible API.
  // If you've configured a custom domain + S3 access, replace this proxy URL
  // with a real presigned URL. For now we expose a same-origin proxy so the
  // iOS client can upload bytes via the worker (worker re-encrypts + writes
  // to R2 on the user's behalf).
  const uploadUrl = new URL(c.req.url);
  uploadUrl.pathname = `/v1/files/${fileId}/upload`;
  uploadUrl.search = "";

  return c.json({ fileId, uploadUrl: uploadUrl.toString() });
});

/**
 * Same-origin upload proxy — iOS PUTs the bytes here. We persist the raw
 * encrypted bytes into R2 under the user's namespace.
 */
router.put("/files/:id/upload", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const id = c.req.param("id");
  const db = drizzle(c.env.DB);
  const fileRow = (
    await db
      .select()
      .from(files)
      .where(and(eq(files.id, id), eq(files.firebaseUid, uid)))
      .limit(1)
  )[0];
  if (!fileRow) return c.json({ error: "not_found" }, 404);

  const body = await c.req.arrayBuffer();
  await c.env.FILES.put(fileRow.r2Key, body, {
    httpMetadata: { contentType: fileRow.mimeType },
  });
  return c.json({ ok: true });
});

router.post("/files/:id/analyze", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const id = c.req.param("id");
  const db = drizzle(c.env.DB);
  const row = (
    await db
      .select()
      .from(files)
      .where(and(eq(files.id, id), eq(files.firebaseUid, uid)))
      .limit(1)
  )[0];
  if (!row) return c.json({ error: "not_found" }, 404);

  const llm = new LLMRouter(c.env);
  try {
    const result = await runLabAnalysis({
      uid,
      fileId: id,
      r2Key: row.r2Key,
      mimeType: row.mimeType,
      env: c.env,
      db,
      llm,
    });
    return c.json({ fileId: id, labReportId: result.labReportId, status: "ready" });
  } catch (err) {
    return c.json({ fileId: id, status: "failed", error: (err as Error).message }, 500);
  }
});

router.get("/files/:id", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const id = c.req.param("id");
  const db = drizzle(c.env.DB);

  const fileRow = (
    await db
      .select()
      .from(files)
      .where(and(eq(files.id, id), eq(files.firebaseUid, uid)))
      .limit(1)
  )[0];
  if (!fileRow) return c.json({ error: "not_found" }, 404);

  const labRow = (
    await db
      .select()
      .from(labReports)
      .where(and(eq(labReports.firebaseUid, uid), eq(labReports.fileId, id)))
      .limit(1)
  )[0];

  return c.json({ file: fileRow, labReport: labRow ?? null });
});

export default router;
