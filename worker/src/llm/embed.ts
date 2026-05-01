/**
 * Embedding helpers — text → 1536-dim vector + Vectorize upsert/query helpers.
 *
 * Model choice:
 *   We use `openai/text-embedding-3-small` via OpenRouter. OpenRouter exposes
 *   it under the `/embeddings` endpoint with the same shape OpenAI uses.
 *   Why: well-supported, 1536 dims (matches Vectorize defaults), cheap, and
 *   a known-good general-purpose embedding for short canonical sentences
 *   (which is what our memories and chunked PDFs are).
 *
 *   To swap to `BAAI/bge-large-en-v1.5` later: change EMBED_MODEL and
 *   re-create the Vectorize index with the new dim count. The functions
 *   below stay the same.
 */

import type { Env } from "../types";

export const EMBED_MODEL = "openai/text-embedding-3-small";
export const EMBED_DIM = 1536;

interface EmbeddingResponse {
  data: Array<{
    embedding: number[];
    index: number;
  }>;
  model?: string;
}

/**
 * Embed a single string. Throws on transport or parse error so callers can
 * decide between hard failure (memory write) and soft skip (search).
 */
export async function embedText(text: string, env: Env): Promise<number[]> {
  if (!text || !text.trim()) {
    throw new Error("embedText: empty input");
  }
  const url = `${env.OPENROUTER_BASE_URL.replace(/\/$/, "")}/embeddings`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
    },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!res.ok) {
    throw new Error(
      `embedText: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`
    );
  }
  const json = (await res.json()) as EmbeddingResponse;
  const vec = json.data?.[0]?.embedding;
  if (!vec || vec.length === 0) {
    throw new Error("embedText: empty embedding");
  }
  return vec;
}

/**
 * Embed multiple strings in one request. OpenRouter accepts arrays.
 */
export async function embedTexts(texts: string[], env: Env): Promise<number[][]> {
  if (texts.length === 0) return [];
  const url = `${env.OPENROUTER_BASE_URL.replace(/\/$/, "")}/embeddings`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
    },
    body: JSON.stringify({ model: EMBED_MODEL, input: texts }),
  });
  if (!res.ok) {
    throw new Error(
      `embedTexts: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`
    );
  }
  const json = (await res.json()) as EmbeddingResponse;
  // Sort by `index` because OpenAI/OpenRouter aren't strictly required to
  // preserve order in the response (in practice they do, but be defensive).
  const sorted = [...(json.data ?? [])].sort((a, b) => a.index - b.index);
  return sorted.map((d) => d.embedding);
}

// ---------------------------------------------------------------------------
// Vectorize helpers — memories index
// ---------------------------------------------------------------------------

/** Per-user namespace string used in Vectorize records. */
export function userNamespace(uid: string): string {
  return `u:${uid}`;
}

export interface MemoryVectorMeta {
  uid: string;
  category: string;
  text: string;
}

export async function upsertMemoryEmbedding(
  uid: string,
  memoryId: string,
  text: string,
  category: string,
  env: Env
): Promise<void> {
  const values = await embedText(text, env);
  await env.VECTOR_INDEX_MEMORIES.upsert([
    {
      id: memoryId,
      values,
      namespace: userNamespace(uid),
      metadata: { uid, category, text } satisfies MemoryVectorMeta,
    },
  ]);
}

export async function deleteMemoryEmbedding(
  memoryId: string,
  env: Env
): Promise<void> {
  await env.VECTOR_INDEX_MEMORIES.deleteByIds([memoryId]);
}

export interface MemoryQueryHit {
  id: string;
  score: number;
  category?: string;
  text?: string;
}

/** Top-k semantic search inside the user's namespace. */
export async function queryMemories(
  uid: string,
  query: string,
  topK: number,
  env: Env
): Promise<MemoryQueryHit[]> {
  const vec = await embedText(query, env);
  const result = await env.VECTOR_INDEX_MEMORIES.query(vec, {
    topK,
    namespace: userNamespace(uid),
    returnMetadata: true,
  });
  return (result.matches ?? []).map((m) => {
    const meta = (m.metadata ?? {}) as Partial<MemoryVectorMeta>;
    return {
      id: m.id,
      score: m.score,
      category: meta.category,
      text: meta.text,
    };
  });
}

// ---------------------------------------------------------------------------
// Vectorize helpers — file chunks index
// ---------------------------------------------------------------------------

export interface FileChunkVectorMeta {
  uid: string;
  fileId: string;
  chunkId: string;
  /** Stored truncated for retrieval-augmented prompts. */
  textPreview: string;
}

export async function upsertFileChunkEmbedding(
  uid: string,
  fileId: string,
  chunkId: string,
  text: string,
  env: Env
): Promise<void> {
  const values = await embedText(text, env);
  await env.VECTOR_INDEX_FILES.upsert([
    {
      id: `${fileId}:${chunkId}`,
      values,
      namespace: userNamespace(uid),
      metadata: {
        uid,
        fileId,
        chunkId,
        textPreview: text.slice(0, 800),
      } satisfies FileChunkVectorMeta,
    },
  ]);
}
