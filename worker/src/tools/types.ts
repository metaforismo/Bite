/**
 * Shared types for the Bite tool framework.
 *
 * A tool is a typed function the LLM can call. Each tool exposes:
 *   - a Zod schema for arguments (validates the model's tool_call.arguments JSON),
 *   - a Zod schema for its result (sanity-checks our own output before sending),
 *   - a JSON Schema (the shape OpenAI tool-calling expects in `parameters`),
 *   - an async `run` that does the work and returns the result.
 *
 * Tools also receive a `ToolContext` carrying the auth uid, the D1 client,
 * the LLM router, the request env, and a `ToolEmitter` for SSE side effects
 * (artifacts, thinking steps, …) that the chat route turns into events.
 */

import type { z } from "zod";
import type { drizzle } from "drizzle-orm/d1";
import type { Env } from "../types";
import type { LLMRouter } from "../llm/router";

export type DB = ReturnType<typeof drizzle>;

/**
 * Health-app snapshot the iOS client supplies in the chat request.
 *
 * The fields are intentionally permissive — different OS versions / opt-ins
 * may omit subsets. Tools should treat every field as possibly-undefined.
 */
export interface HealthSnapshot {
  rhr?: number; // resting heart rate, bpm
  hrv?: number; // SDNN ms, 7-day average
  sleepHours?: number; // last night's total
  weightKg?: number;
  heightCm?: number;
  activeEnergyKcal?: number; // today's active energy
  steps?: number; // today's steps
  respiratoryRate?: number; // breaths/min, last night
  sleepCoreMinutes?: number; // last night's core sleep
  sleepDeepMinutes?: number; // last night's deep sleep
  sleepRemMinutes?: number; // last night's REM sleep
  hrvBaseline60d?: number; // mean of daily HRV averages, trailing 60 days
  rhrBaseline60d?: number; // mean of daily RHR averages, trailing 60 days
  capturedAt?: string; // ISO 8601 timestamp
  missing?: string[]; // field names the client could not read
  // Any extra fields the client adds — tools must ignore unknown keys.
  [k: string]: unknown;
}

/** A tool may emit one or more SSE side effects during its run. */
export interface ArtifactEmission {
  /** Stable id — re-used across versions of the same artifact. */
  id: string;
  type: string;
  payload: unknown;
  /** Monotonically increasing per id. */
  version: number;
}

export interface ThinkingStepEmission {
  /** Stable id so the UI can collapse a step's running -> done states. */
  id: string;
  label: string;
  status: "running" | "done" | "failed";
  detail?: string;
}

export interface ToolEmitter {
  artifact(a: ArtifactEmission): void;
  thinking(step: ThinkingStepEmission): void;
}

export interface ToolContext {
  uid: string;
  email?: string;
  threadId?: string;
  messageId?: string;
  db: DB;
  env: Env;
  llm: LLMRouter;
  /** Health snapshot supplied by the iOS client, if any. */
  healthSnapshot?: HealthSnapshot;
  /** Side-effect channel — only populated during a streaming chat turn. */
  emit: ToolEmitter;
}

export interface ToolDefinition<
  Input extends z.ZodTypeAny = z.ZodTypeAny,
  Output extends z.ZodTypeAny = z.ZodTypeAny,
> {
  name: string;
  description: string;
  /** Zod schema for input args. */
  input: Input;
  /** Zod schema for output. The dispatcher validates against this. */
  output: Output;
  /**
   * JSON Schema (as expected by OpenAI tool-calling) describing `input`.
   * Hand-written so we can tune descriptions; we also assert it parses
   * input via zod at runtime, so the two cannot drift silently.
   */
  parameters: Record<string, unknown>;
  run: (args: z.infer<Input>, ctx: ToolContext) => Promise<z.infer<Output>>;
}

/** Constructor that preserves the input/output generics. */
export function defineTool<
  Input extends z.ZodTypeAny,
  Output extends z.ZodTypeAny,
>(t: ToolDefinition<Input, Output>): ToolDefinition<Input, Output> {
  return t;
}

/** Shape of an OpenAI-style entry in the `tools` array. */
export interface OpenAIToolSpec {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}
