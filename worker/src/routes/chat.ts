import { Hono } from "hono";
import { drizzle } from "drizzle-orm/d1";
import { and, desc, eq } from "drizzle-orm";
import { z } from "zod";
import { messages, threads } from "../db/schema";
import type { AppBindings } from "../types";

/**
 * Chat thread routes.
 *
 *   POST /v1/chat/threads          create a new thread
 *   GET  /v1/chat/threads          list this user's threads (paginated)
 *   GET  /v1/chat/threads/:id      thread + last 100 messages
 */
const chat = new Hono<AppBindings>();

const createThreadBody = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
  })
  .strict();

chat.post("/chat/threads", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  let body: unknown = {};
  try {
    body = await c.req.json();
  } catch {
    body = {};
  }
  const parsed = createThreadBody.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "invalid_body", issues: parsed.error.issues }, 400);
  }
  const now = Date.now();
  const id = crypto.randomUUID();
  const title = parsed.data.title ?? "New chat";

  const db = drizzle(c.env.DB);
  await db.insert(threads).values({
    id,
    firebaseUid: uid,
    title,
    pinned: false,
    lastMessageAt: now,
    createdAt: now,
  });

  return c.json({ id, title, createdAt: now }, 201);
});

chat.get("/chat/threads", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const db = drizzle(c.env.DB);
  const rows = await db
    .select()
    .from(threads)
    .where(eq(threads.firebaseUid, uid))
    .orderBy(desc(threads.lastMessageAt))
    .limit(50);
  return c.json({ threads: rows });
});

chat.get("/chat/threads/:id", async (c) => {
  const uid = c.get("uid");
  if (!uid) return c.json({ error: "unauthorized" }, 401);
  const id = c.req.param("id");
  const db = drizzle(c.env.DB);

  const threadRows = await db
    .select()
    .from(threads)
    .where(and(eq(threads.id, id), eq(threads.firebaseUid, uid)))
    .limit(1);

  const thread = threadRows[0];
  if (!thread) {
    return c.json({ error: "not_found" }, 404);
  }

  const messageRows = await db
    .select()
    .from(messages)
    .where(eq(messages.threadId, id))
    .orderBy(desc(messages.createdAt))
    .limit(100);

  // Reverse so callers receive messages oldest-first.
  const ordered = messageRows.slice().reverse();

  return c.json({ thread, messages: ordered });
});

export default chat;
