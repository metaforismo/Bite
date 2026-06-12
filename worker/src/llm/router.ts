import OpenAI from "openai";
import type { Env } from "../types";

/**
 * Bite LLM router — thin wrapper around the OpenAI SDK pointed at OpenRouter.
 *
 * OpenRouter implements the OpenAI Chat Completions API on a single endpoint
 * with multiple model providers behind it, so we pass `baseURL =
 * env.OPENROUTER_BASE_URL` and `apiKey = env.OPENROUTER_API_KEY` and then
 * pick a model id per call.
 */

export type ChatRole = "system" | "user" | "assistant" | "tool";

export interface ToolCallRef {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
}

export interface ChatMessage {
  role: ChatRole;
  content: string;
  // Optional name for `tool` role messages.
  name?: string;
  // Optional tool_call_id for tool replies.
  tool_call_id?: string;
  // Tool calls the assistant emitted — required on assistant turns that
  // precede `tool` replies, or providers reject the transcript.
  tool_calls?: ToolCallRef[];
}

export interface ChatTool {
  type: "function";
  function: {
    name: string;
    description?: string;
    parameters: Record<string, unknown>;
  };
}

export interface ChatOptions {
  messages: ChatMessage[];
  tools?: ChatTool[];
  /** Explicit model id override. Bypasses the cheap/vision routing. */
  model?: string;
  /** If true, use a vision-capable model. */
  vision?: boolean;
  /** If true, route to the cheap/fast tier. */
  cheap?: boolean;
  /** If true, return an AsyncGenerator of streaming chunks. */
  stream?: boolean;
  /** Optional override for sampling. */
  temperature?: number;
  /** Optional max output tokens. */
  maxTokens?: number;
  /** Abort signal propagated from the incoming request. */
  signal?: AbortSignal;
}

export interface ToolCallDelta {
  index: number;
  id?: string;
  name?: string;
  argumentsDelta?: string;
}

export interface ChatChunk {
  /** Incremental assistant text, if any. */
  delta?: string;
  /** Tool call deltas, if any. */
  toolCallDeltas?: ToolCallDelta[];
  /** Final stop reason on the last chunk. */
  finishReason?: string | null;
}

export interface ChatMessageResult {
  role: "assistant";
  content: string;
  toolCalls?: Array<{
    id: string;
    type: "function";
    function: { name: string; arguments: string };
  }>;
  finishReason: string | null;
  model: string;
}

/**
 * Default models. Edit here to swap the routing.
 *
 * Routing goes through OpenRouter, so any provider works; defaults are
 * OpenAI's GPT-5 family. Embeddings (see `embed.ts`) already use OpenAI's
 * `text-embedding-3-small`.
 */
export const DEFAULT_MODELS = {
  cheap: "openai/gpt-5.4-mini",
  vision: "openai/gpt-5.4",
  primary: "openai/gpt-5.5",
  /** Mid tier — accurate structured output at lower cost. Available via explicit `model:` override. */
  mid: "openai/gpt-5.4",
} as const;

export class LLMRouter {
  private client: OpenAI;

  constructor(env: Env) {
    this.client = new OpenAI({
      apiKey: env.OPENROUTER_API_KEY,
      baseURL: env.OPENROUTER_BASE_URL,
      // Workers runtime has fetch + AbortController; the SDK uses them.
    });
  }

  /**
   * Pure routing decision. Exposed as a static so it can be unit-tested
   * without instantiating the SDK.
   */
  static routeFor(opts: {
    model?: string;
    vision?: boolean;
    cheap?: boolean;
  }): string {
    if (opts.model) return opts.model;
    if (opts.cheap) return DEFAULT_MODELS.cheap;
    if (opts.vision) return DEFAULT_MODELS.vision;
    return DEFAULT_MODELS.primary;
  }

  /**
   * Run a chat completion. When `stream: true` returns an AsyncGenerator
   * yielding ChatChunk objects; otherwise resolves to a ChatMessageResult.
   */
  chat(opts: ChatOptions & { stream: true }): AsyncGenerator<ChatChunk, void, unknown>;
  chat(opts: ChatOptions & { stream?: false }): Promise<ChatMessageResult>;
  chat(opts: ChatOptions): Promise<ChatMessageResult> | AsyncGenerator<ChatChunk, void, unknown> {
    const model = LLMRouter.routeFor(opts);
    if (opts.stream) {
      return this.#streamChat(model, opts);
    }
    return this.#completeChat(model, opts);
  }

  static #mapMessages(messages: ChatMessage[]): OpenAI.Chat.ChatCompletionMessageParam[] {
    return messages.map((m) => ({
      role: m.role,
      content: m.content,
      ...(m.name ? { name: m.name } : {}),
      ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {}),
      ...(m.tool_calls ? { tool_calls: m.tool_calls } : {}),
    })) as unknown as OpenAI.Chat.ChatCompletionMessageParam[];
  }

  async #completeChat(model: string, opts: ChatOptions): Promise<ChatMessageResult> {
    const resp = await this.client.chat.completions.create(
      {
        model,
        messages: LLMRouter.#mapMessages(opts.messages),
        tools: opts.tools as unknown as OpenAI.Chat.ChatCompletionTool[] | undefined,
        temperature: opts.temperature,
        max_tokens: opts.maxTokens,
        stream: false,
      },
      { signal: opts.signal }
    );

    const choice = resp.choices[0];
    const message = choice?.message;
    return {
      role: "assistant",
      content: message?.content ?? "",
      toolCalls: message?.tool_calls?.map((tc) => ({
        id: tc.id,
        type: "function" as const,
        function: {
          name: tc.function.name,
          arguments: tc.function.arguments,
        },
      })),
      finishReason: choice?.finish_reason ?? null,
      model: resp.model,
    };
  }

  /**
   * Convenience helper for tools that just need a one-shot text completion.
   * `task` picks the routing tier ("reasoning" → primary, "cheap" → fast
   * tier, "vision" → multimodal tier).
   */
  async completeText(opts: {
    task: "reasoning" | "cheap" | "vision";
    system: string;
    user: string;
    maxTokens?: number;
    temperature?: number;
  }): Promise<string> {
    const result = await this.chat({
      messages: [
        { role: "system", content: opts.system },
        { role: "user", content: opts.user },
      ],
      cheap: opts.task === "cheap",
      vision: opts.task === "vision",
      temperature: opts.temperature,
      maxTokens: opts.maxTokens,
    });
    return result.content;
  }

  async *#streamChat(
    model: string,
    opts: ChatOptions
  ): AsyncGenerator<ChatChunk, void, unknown> {
    const stream = await this.client.chat.completions.create(
      {
        model,
        messages: LLMRouter.#mapMessages(opts.messages),
        tools: opts.tools as unknown as OpenAI.Chat.ChatCompletionTool[] | undefined,
        temperature: opts.temperature,
        max_tokens: opts.maxTokens,
        stream: true,
      },
      { signal: opts.signal }
    );

    for await (const part of stream) {
      const choice = part.choices[0];
      if (!choice) continue;
      const delta = choice.delta;
      const out: ChatChunk = {
        finishReason: choice.finish_reason ?? null,
      };
      if (typeof delta?.content === "string" && delta.content.length > 0) {
        out.delta = delta.content;
      }
      if (delta?.tool_calls && delta.tool_calls.length > 0) {
        out.toolCallDeltas = delta.tool_calls.map((tc) => ({
          index: tc.index ?? 0,
          id: tc.id,
          name: tc.function?.name,
          argumentsDelta: tc.function?.arguments,
        }));
      }
      yield out;
    }
  }
}
