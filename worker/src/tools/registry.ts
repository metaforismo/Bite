/**
 * Tool registry — the single source of truth the chat route uses to:
 *   1. Build the `tools` array passed to OpenRouter for tool calling.
 *   2. Dispatch a model-emitted tool_call to the right `run` function with
 *      validated args, returning a validated, JSON-serializable result.
 *
 * Tools register themselves by importing this module and pushing into
 * `ALL_TOOLS`. The registry is constructed once per request from `ALL_TOOLS`,
 * so test code can compose subsets if needed.
 */

import type { OpenAIToolSpec, ToolContext, ToolDefinition } from "./types";

import { getProfileTool } from "./getProfile";
import { getDayLogTool } from "./getDayLog";
import { getRangeTool } from "./getRange";
import { getHealthSnapshotTool } from "./getHealthSnapshot";
import { addFoodEntryTool } from "./addFoodEntry";
import { correctFoodEntryTool } from "./correctFoodEntry";
import { searchMemoriesTool } from "./searchMemories";
import { addMemoryTool } from "./addMemory";
import { removeMemoryTool } from "./removeMemory";
import { scheduleCheckInTool } from "./scheduleCheckIn";
import { analyzeImpactTool } from "./analyzeImpact";
import { predictTool } from "./predict";
import { proposeWorkoutTool } from "./proposeWorkout";
import { proposePlanTool } from "./proposePlan";
import { addLabReportTool } from "./addLabReport";
import { getBiomarkersTool } from "./getBiomarkers";
import { addDrinkTool } from "./addDrink";
import { getDrinkLogTool } from "./getDrinkLog";
import { setActivityStatusTool } from "./setActivityStatus";
import { getActivityStatusTool } from "./getActivityStatus";
import { addCycleEntryTool } from "./addCycleEntry";
import { getCycleDataTool } from "./getCycleData";
import { getCycleInsightTool } from "./getCycleInsight";
import { completeWorkoutTool } from "./completeWorkout";
import { computeBiologicalAgeTool } from "./computeBiologicalAge";
import { classifyJournalEntryTool } from "./classifyJournalEntry";
import { analyzeImpactByTagTool } from "./analyzeImpactByTag";
import { addWeightEntryTool } from "./addWeightEntry";

/** Every tool the agent can call. Ordering does not matter to the model. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const ALL_TOOLS: ToolDefinition<any, any>[] = [
  getProfileTool,
  getDayLogTool,
  getRangeTool,
  getHealthSnapshotTool,
  addFoodEntryTool,
  correctFoodEntryTool,
  searchMemoriesTool,
  addMemoryTool,
  removeMemoryTool,
  scheduleCheckInTool,
  analyzeImpactTool,
  predictTool,
  proposeWorkoutTool,
  proposePlanTool,
  addLabReportTool,
  getBiomarkersTool,
  // V2 wave (B2–B8)
  addDrinkTool,
  getDrinkLogTool,
  setActivityStatusTool,
  getActivityStatusTool,
  addCycleEntryTool,
  getCycleDataTool,
  getCycleInsightTool,
  completeWorkoutTool,
  computeBiologicalAgeTool,
  classifyJournalEntryTool,
  analyzeImpactByTagTool,
  addWeightEntryTool,
];

export interface DispatchResult {
  tool: string;
  /** Parsed and validated output (already serializable). */
  output: unknown;
  /** Whether the call succeeded; if false, `output` is `{ error: string }`. */
  ok: boolean;
  /** Time spent inside `run`, in ms. */
  latencyMs: number;
}

export class ToolRegistry {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private byName = new Map<string, ToolDefinition<any, any>>();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  constructor(tools: ToolDefinition<any, any>[]) {
    for (const t of tools) {
      if (this.byName.has(t.name)) {
        throw new Error(`duplicate tool name: ${t.name}`);
      }
      this.byName.set(t.name, t);
    }
  }

  /** OpenAI-style tools array for the chat completion request. */
  toOpenAITools(): OpenAIToolSpec[] {
    return [...this.byName.values()].map((t) => ({
      type: "function" as const,
      function: {
        name: t.name,
        description: t.description,
        parameters: t.parameters,
      },
    }));
  }

  has(name: string): boolean {
    return this.byName.has(name);
  }

  get(name: string) {
    return this.byName.get(name);
  }

  /**
   * Dispatch a tool call. `argsRaw` is the JSON string the model emitted
   * (or an already-parsed object). We:
   *   1. JSON-parse if needed,
   *   2. zod-validate against `input`,
   *   3. run the tool,
   *   4. zod-validate the output,
   *   5. return a serializable DispatchResult.
   *
   * Throws never — errors become `{ ok: false, output: { error } }`.
   */
  async dispatch(
    name: string,
    argsRaw: string | unknown,
    ctx: ToolContext
  ): Promise<DispatchResult> {
    const startedAt = Date.now();
    const tool = this.byName.get(name);
    if (!tool) {
      return {
        tool: name,
        output: { error: `unknown_tool: ${name}` },
        ok: false,
        latencyMs: Date.now() - startedAt,
      };
    }

    let parsed: unknown;
    try {
      parsed = typeof argsRaw === "string" ? JSON.parse(argsRaw) : argsRaw;
    } catch (err) {
      return {
        tool: name,
        output: { error: `invalid_json: ${(err as Error).message}` },
        ok: false,
        latencyMs: Date.now() - startedAt,
      };
    }

    const inputCheck = tool.input.safeParse(parsed);
    if (!inputCheck.success) {
      return {
        tool: name,
        output: {
          error: "invalid_args",
          issues: inputCheck.error.issues,
        },
        ok: false,
        latencyMs: Date.now() - startedAt,
      };
    }

    let result: unknown;
    try {
      result = await tool.run(inputCheck.data, ctx);
    } catch (err) {
      console.error(`[tools] ${name} threw`, err);
      return {
        tool: name,
        output: { error: (err as Error).message ?? "tool_failed" },
        ok: false,
        latencyMs: Date.now() - startedAt,
      };
    }

    const outputCheck = tool.output.safeParse(result);
    if (!outputCheck.success) {
      console.error(`[tools] ${name} returned invalid output`, outputCheck.error);
      return {
        tool: name,
        output: {
          error: "invalid_output",
          issues: outputCheck.error.issues,
        },
        ok: false,
        latencyMs: Date.now() - startedAt,
      };
    }

    return {
      tool: name,
      output: outputCheck.data,
      ok: true,
      latencyMs: Date.now() - startedAt,
    };
  }
}

/** Build a registry containing every tool. */
export function buildRegistry(): ToolRegistry {
  return new ToolRegistry(ALL_TOOLS);
}
