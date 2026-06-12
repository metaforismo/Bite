/**
 * Lab-document analysis pipeline.
 *
 *   1. Pull the encrypted bytes out of R2.
 *   2. Decrypt with the per-user AES-GCM key.
 *   3. Extract text:
 *        - PDF: best-effort string scan (Workers can't run pdfjs reliably).
 *        - image: hand the base64 image to the vision model and let it
 *          transcribe + structure in one pass.
 *   4. Hand the extracted text to a mid-tier pass with a strict JSON schema
 *      asking for biomarkers + a "discuss with clinician" summary.
 *   5. Persist `lab_reports` + `biomarkers` rows.
 *
 * The pipeline is intentionally synchronous — Cloudflare Workers don't have
 * background job queues by default, and lab parsing typically completes well
 * within the streaming chat-turn deadline (~30s end-to-end).
 */
import { and, eq } from "drizzle-orm";
import type { Env } from "../types";
import type { DB } from "../tools/types";
import { decryptForUser } from "../encryption";
import { biomarkers as biomarkersTable, labReports } from "../db/schema";
import { DEFAULT_MODELS } from "../llm/router";
import type { LLMRouter } from "../llm/router";
import { z } from "zod";

const BiomarkerSchema = z.object({
  name: z.string(),
  category: z.string(),
  value: z.number(),
  unit: z.string(),
  refLow: z.number().nullable().optional(),
  refHigh: z.number().nullable().optional(),
  status: z.enum(["in_range", "high", "low", "unknown"]).default("unknown"),
});

const ParseSchema = z.object({
  title: z.string(),
  takenAt: z.string().optional(),
  confidence: z.number().min(0).max(1),
  summary: z.string(),
  biomarkers: z.array(BiomarkerSchema),
});

export interface RunArgs {
  uid: string;
  fileId: string;
  r2Key: string;
  mimeType: string;
  env: Env;
  db: DB;
  llm: LLMRouter;
  title?: string;
  onThinking?: (
    label: string,
    status: "running" | "done" | "failed",
    id?: string
  ) => void;
}

export interface RunResult {
  labReportId: string;
  summary?: string;
}

const SYSTEM_PROMPT = `You parse clinical lab documents into structured biomarker rows.
Return ONLY a JSON object matching the schema. Be conservative:
- mark a biomarker "in_range" only if the value sits inside [refLow, refHigh],
- otherwise "high" or "low" relative to the listed reference range,
- "unknown" if no reference range is on the document.
Always include the strings "Not a diagnosis" and "Discuss with clinician" in the summary field.`;

export async function runLabAnalysis(args: RunArgs): Promise<RunResult> {
  const { uid, fileId, r2Key, mimeType, env, db, llm, onThinking } = args;
  const labReportId = crypto.randomUUID();
  const now = Date.now();

  await db.insert(labReports).values({
    id: labReportId,
    firebaseUid: uid,
    fileId,
    title: args.title ?? "Lab report",
    takenAt: now,
    sourceUrl: r2Key,
    confidence: 0,
    status: "extracting",
    createdAt: now,
  });

  // 1. Pull from R2.
  onThinking?.("Reading the lab document", "running", "lab.fetch");
  const obj = await env.FILES.get(r2Key);
  if (!obj) {
    await markFailed(db, uid, labReportId, "file_missing");
    throw new Error("file_missing");
  }
  const cipherBuffer = await obj.arrayBuffer();

  // 2. Decrypt.
  let plaintext: Uint8Array;
  try {
    plaintext = await decryptForUser(new Uint8Array(cipherBuffer), uid, env.FILE_ENCRYPTION_MASTER_KEY);
  } catch {
    // Some files may have been uploaded without encryption (e.g. presigned PUT
    // direct from the iOS client). Fall back to treating the bytes as-is.
    plaintext = new Uint8Array(cipherBuffer);
  }
  onThinking?.("Reading the lab document", "done", "lab.fetch");

  // 3. Extract.
  onThinking?.("Extracting text", "running", "lab.extract");
  const isPdf = mimeType.includes("pdf");
  const isImage = mimeType.startsWith("image/");
  let extractedText = "";
  let useVisionDirect = false;
  let imageBase64: string | undefined;

  if (isPdf) {
    extractedText = scanPdfStrings(plaintext);
    if (extractedText.length < 80) {
      // Likely scanned PDF — fall back to vision.
      useVisionDirect = true;
      imageBase64 = bytesToBase64(plaintext);
    }
  } else if (isImage) {
    useVisionDirect = true;
    imageBase64 = bytesToBase64(plaintext);
  } else {
    extractedText = new TextDecoder().decode(plaintext);
  }
  onThinking?.("Extracting text", "done", "lab.extract");

  // 4. Structure with the LLM.
  onThinking?.("Identifying biomarkers", "running", "lab.identify");
  await db
    .update(labReports)
    .set({ status: "parsing" })
    .where(and(eq(labReports.id, labReportId), eq(labReports.firebaseUid, uid)));

  const userMessage = useVisionDirect
    ? `Here is a lab document image (mime: ${mimeType}). Extract every biomarker you can read. Image (base64, ${mimeType}):\n${imageBase64?.slice(0, 200_000)}`
    : `Lab document text:\n\n${extractedText.slice(0, 60_000)}`;

  const parsed = await llm.chat({
    cheap: false,
    vision: useVisionDirect,
    model: useVisionDirect ? undefined : DEFAULT_MODELS.mid,
    temperature: 0,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      {
        role: "user",
        content: `${userMessage}\n\nReturn JSON of shape:\n${JSON.stringify(
          {
            title: "string",
            takenAt: "ISO date string (optional)",
            confidence: "0..1",
            summary: "string with 'Not a diagnosis' and 'Discuss with clinician'",
            biomarkers: [
              {
                name: "string",
                category: "Lipids|Inflammation|Metabolic|Hematology|Hormones|Other",
                value: 0,
                unit: "string",
                refLow: 0,
                refHigh: 0,
                status: "in_range|high|low|unknown",
              },
            ],
          },
          null,
          2
        )}`,
      },
    ],
  });

  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(extractFirstJsonObject(parsed.content));
  } catch (err) {
    await markFailed(db, uid, labReportId, `llm_parse_failed: ${(err as Error).message}`);
    throw err;
  }
  const validated = ParseSchema.safeParse(parsedJson);
  if (!validated.success) {
    await markFailed(db, uid, labReportId, "schema_mismatch");
    throw new Error("schema_mismatch");
  }
  onThinking?.("Identifying biomarkers", "done", "lab.identify");

  // 5. Persist.
  onThinking?.("Saving biomarkers", "running", "lab.save");
  await db
    .update(labReports)
    .set({
      title: validated.data.title || (args.title ?? "Lab report"),
      confidence: validated.data.confidence,
      status: "ready",
    })
    .where(and(eq(labReports.id, labReportId), eq(labReports.firebaseUid, uid)));

  for (const m of validated.data.biomarkers) {
    await db.insert(biomarkersTable).values({
      id: crypto.randomUUID(),
      firebaseUid: uid,
      labReportId,
      name: m.name,
      category: m.category,
      value: m.value,
      unit: m.unit,
      refLow: m.refLow ?? null,
      refHigh: m.refHigh ?? null,
      status: m.status,
      takenAt: now,
    });
  }
  onThinking?.("Saving biomarkers", "done", "lab.save");

  return { labReportId, summary: validated.data.summary };
}

function scanPdfStrings(bytes: Uint8Array): string {
  // A pragmatic ASCII scan over a PDF's body. Handles text that's stored as
  // literal strings inside `(...)` or `[...]` text-show operators. Misses
  // CID-encoded fonts and image-only PDFs (those route to vision instead).
  const decoded = new TextDecoder("latin1").decode(bytes);
  const matches = decoded.match(/\(([^()\\]{2,})\)/g) ?? [];
  const stringContent = matches
    .map((m) => m.slice(1, -1).replace(/\\n/g, "\n").replace(/\\r/g, ""))
    .filter((s) => /[A-Za-z]/.test(s))
    .join(" ");
  return stringContent;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  // btoa is available in Workers.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (globalThis as any).btoa(binary);
}

function extractFirstJsonObject(content: string): string {
  // Models sometimes wrap output in ```json fences.
  const fence = content.match(/```json\s*([\s\S]*?)```/);
  if (fence) return fence[1];
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  if (start >= 0 && end > start) return content.slice(start, end + 1);
  return content;
}

async function markFailed(db: DB, uid: string, labReportId: string, reason: string) {
  await db
    .update(labReports)
    .set({ status: "failed", errorMessage: reason })
    .where(and(eq(labReports.id, labReportId), eq(labReports.firebaseUid, uid)));
}
