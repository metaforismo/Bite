import Foundation

/// Parses an SSE byte stream from the Bite Worker.
/// Each emitted `SSEEvent` corresponds to a `event:` + `data:` block separated by a blank line.
struct SSEEvent: Sendable {
    let event: String          // `thread_id` | `thinking_step` | `text_delta` | `tool_call` | `tool_result` | `artifact` | `error` | `done`
    let dataJSON: String       // Raw JSON; caller decodes per event type.
}

/// Streaming SSE decoder. Incrementally consumes UTF-8 chunks and yields complete events.
struct SSEParser {
    private(set) var buffer: String = ""

    mutating func feed(_ chunk: Data) -> [SSEEvent] {
        guard let text = String(data: chunk, encoding: .utf8) else { return [] }
        buffer.append(text)
        return drain()
    }

    mutating func drain() -> [SSEEvent] {
        var events: [SSEEvent] = []
        while let range = buffer.range(of: "\n\n") {
            let block = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let event = parseBlock(block) {
                events.append(event)
            }
        }
        return events
    }

    private func parseBlock(_ block: String) -> SSEEvent? {
        var event: String?
        var dataLines: [String] = []
        for rawLine in block.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(":") || line.isEmpty { continue }       // comment or padding
            if let colon = line.firstIndex(of: ":") {
                let field = String(line[..<colon])
                var value = String(line[line.index(after: colon)...])
                if value.first == " " { value.removeFirst() }
                switch field {
                case "event": event = value
                case "data":  dataLines.append(value)
                default: break                                          // ignore id/retry for now
                }
            }
        }
        guard let event else { return nil }
        return SSEEvent(event: event, dataJSON: dataLines.joined(separator: "\n"))
    }
}
