import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { biomarkers, files, labReports } from "../db/schema";
import { defineTool } from "./types";
import { runLabAnalysis } from "../jobs/analyze";

const Input = z
  .object({
    fileId: z.string().uuid(),
    title: z.string().optional(),
  })
  .strict();

const Output = z.object({
  labReportId: z.string(),
  biomarkerCount: z.number(),
  status: z.enum(["pending", "extracting", "parsing", "ready", "failed"]),
  artifactId: z.string(),
});

/**
 * Kicks off the lab-analysis pipeline for an already-uploaded file. The job
 * runs inline (Workers don't have background job queues by default — the call
 * stays open while the LLM passes complete). On completion we have a fresh
 * `lab_reports` row + `biomarkers` rows, and we emit a `lab_report` artifact
 * over the SSE stream so the chat UI updates immediately.
 */
export const addLabReportTool = defineTool({
  name: "add_lab_report",
  description:
    "Analyze an uploaded clinical file (PDF or image). Extracts biomarkers, classifies them as in-range / high / low, and emits a `lab_report` artifact. Always include the safety strings 'Not a diagnosis' and 'Discuss with clinician' in the user-facing summary.",
  input: Input,
  output: Output,
  parameters: {
    type: "object",
    properties: {
      fileId: { type: "string", description: "UUID of an already-uploaded file." },
      title: { type: "string", description: "Optional human title for the report." },
    },
    required: ["fileId"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    // Ownership check
    const fileRow = (
      await ctx.db
        .select()
        .from(files)
        .where(and(eq(files.id, args.fileId), eq(files.firebaseUid, ctx.uid)))
        .limit(1)
    )[0];
    if (!fileRow) {
      throw new Error("file_not_found_or_unauthorized");
    }

    ctx.emit.thinking({
      id: "lab.fetch",
      label: "Reading the lab document",
      status: "running",
    });

    const result = await runLabAnalysis({
      uid: ctx.uid,
      fileId: args.fileId,
      r2Key: fileRow.r2Key,
      mimeType: fileRow.mimeType,
      env: ctx.env,
      db: ctx.db,
      llm: ctx.llm,
      title: args.title,
      onThinking: (label, status, id) => ctx.emit.thinking({ id: id ?? `lab.${label}`, label, status }),
    });

    // Final lookup so the artifact payload is whatever actually persisted.
    const labRow = (
      await ctx.db
        .select()
        .from(labReports)
        .where(and(eq(labReports.id, result.labReportId), eq(labReports.firebaseUid, ctx.uid)))
        .limit(1)
    )[0];
    const markerRows = await ctx.db
      .select()
      .from(biomarkers)
      .where(and(eq(biomarkers.firebaseUid, ctx.uid), eq(biomarkers.labReportId, result.labReportId)));

    const artifactId = result.labReportId;
    ctx.emit.artifact({
      id: artifactId,
      type: "lab_report",
      version: 1,
      payload: {
        title: labRow?.title ?? args.title ?? "Lab report",
        takenAt: labRow ? new Date(labRow.takenAt).toISOString() : null,
        confidence: labRow?.confidence ?? 0.5,
        sourceFileName: fileRow.r2Key.split("/").pop(),
        biomarkers: markerRows.map((m) => ({
          id: m.id,
          name: m.name,
          category: m.category ?? "Other",
          value: m.value,
          unit: m.unit,
          refLow: m.refLow,
          refHigh: m.refHigh,
          status: m.status ?? "unknown",
        })),
        summary:
          result.summary ??
          "Not a diagnosis. Discuss any out-of-range values with a clinician before changing supplements, medication, or routines.",
      },
    });

    return {
      labReportId: result.labReportId,
      biomarkerCount: markerRows.length,
      status: (labRow?.status as "ready" | "failed" | "parsing" | "extracting" | "pending") ?? "ready",
      artifactId,
    };
  },
});
