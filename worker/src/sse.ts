/**
 * Server-Sent Events helpers.
 *
 * The Bite agent streams structured events (not just raw token deltas) so
 * the client can render thinking steps, tool calls, and artifacts as they
 * happen. Each event is encoded as:
 *
 *   event: <type>
 *   data: <JSON>
 *   \n\n
 *
 * Event types are deliberately a closed union — keep the client and server
 * in sync.
 */

export type SSEEventType =
  | "thread_id"
  | "thinking_step"
  | "text_delta"
  | "tool_call"
  | "tool_result"
  | "artifact"
  | "error"
  | "done";

export interface SSEEvent<T = unknown> {
  type: SSEEventType;
  data: T;
}

/** Encode a single SSE frame. */
export function encodeSSE(event: SSEEvent): string {
  const payload = typeof event.data === "string" ? event.data : JSON.stringify(event.data);
  return `event: ${event.type}\ndata: ${payload}\n\n`;
}

/**
 * Build an SSE Response from an AsyncGenerator of events.
 *
 * The generator may throw — we catch and emit a final `error` frame, then a
 * `done` frame, before closing the stream.
 */
export function sseResponse(
  source: AsyncGenerator<SSEEvent, void, unknown>,
  init?: ResponseInit
): Response {
  const encoder = new TextEncoder();

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      try {
        for await (const evt of source) {
          controller.enqueue(encoder.encode(encodeSSE(evt)));
        }
        controller.enqueue(encoder.encode(encodeSSE({ type: "done", data: {} })));
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        controller.enqueue(
          encoder.encode(encodeSSE({ type: "error", data: { message } }))
        );
        controller.enqueue(encoder.encode(encodeSSE({ type: "done", data: {} })));
      } finally {
        controller.close();
      }
    },
    cancel() {
      // Consumer disconnected — stop the source generator so tool dispatch
      // and DB writes don't keep running against a closed stream.
      void source.return(undefined).catch(() => {});
    },
  });

  return new Response(stream, {
    ...init,
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
      ...(init?.headers ?? {}),
    },
  });
}
