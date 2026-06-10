import Foundation

/// Decoded SSE events sent by the Bite Worker. Mirrors `worker/src/sse.ts`.
enum CoachStreamEvent: Sendable {
    case threadId(UUID)
    case thinkingStep(label: String, status: ThinkingStepStatus)
    case textDelta(String)
    case toolCall(name: String, argsJSON: String)
    case toolResult(name: String, resultJSON: String)
    case artifact(ArtifactPayload)
    case error(String)
    case done

    enum ThinkingStepStatus: String, Decodable, Sendable { case running, done, failed }

    struct ArtifactPayload: Decodable, Sendable {
        let id: UUID
        let type: String
        let payload: PayloadEnvelope
        let version: Int

        struct PayloadEnvelope: Decodable, Sendable {
            let json: String
            init(from decoder: Decoder) throws {
                // Worker sends `payload` as a JSON object. We retain it as a string
                // so iOS can decode into the artifact-specific struct on demand.
                let container = try decoder.singleValueContainer()
                if let raw = try? container.decode(String.self) {
                    self.json = raw
                } else if let dict = try? container.decode([String: AnyDecodable].self) {
                    self.json = (try? String(data: JSONEncoder().encode(dict), encoding: .utf8)) ?? "{}"
                } else {
                    self.json = "{}"
                }
            }
        }
    }
}

private struct AnyDecodable: Decodable, Encodable {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode([AnyDecodable].self) { value = v.map(\.value) }
        else if let v = try? c.decode([String: AnyDecodable].self) { value = v.mapValues(\.value) }
        else if c.decodeNil() { value = NSNull() }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map { AnyDecodable(value: $0) })
        case let v as [String: Any]: try c.encode(v.mapValues { AnyDecodable(value: $0) })
        case is NSNull: try c.encodeNil()
        default: try c.encodeNil()
        }
    }
}

extension SSEEvent {
    func decoded() -> CoachStreamEvent? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch event {
        case "thread_id":
            struct P: Decodable { let threadId: UUID; enum CodingKeys: String, CodingKey { case threadId = "thread_id" } }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return nil }
            return .threadId(p.threadId)
        case "thinking_step":
            struct P: Decodable { let label: String; let status: CoachStreamEvent.ThinkingStepStatus }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return nil }
            return .thinkingStep(label: p.label, status: p.status)
        case "text_delta":
            struct P: Decodable { let chunk: String }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return nil }
            return .textDelta(p.chunk)
        case "tool_call":
            struct P: Decodable { let tool: String; let args: AnyDecodable }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return nil }
            let argsString = (try? String(data: JSONEncoder().encode(p.args), encoding: .utf8)) ?? "{}"
            return .toolCall(name: p.tool, argsJSON: argsString)
        case "tool_result":
            struct P: Decodable { let tool: String; let result: AnyDecodable }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return nil }
            let resultString = (try? String(data: JSONEncoder().encode(p.result), encoding: .utf8)) ?? "{}"
            return .toolResult(name: p.tool, resultJSON: resultString)
        case "artifact":
            guard let data = dataJSON.data(using: .utf8),
                  let payload = try? decoder.decode(CoachStreamEvent.ArtifactPayload.self, from: data)
            else { return nil }
            return .artifact(payload)
        case "error":
            struct P: Decodable { let message: String }
            guard let data = dataJSON.data(using: .utf8), let p = try? decoder.decode(P.self, from: data) else { return .error("unknown") }
            return .error(p.message)
        case "done":
            return .done
        default:
            return nil
        }
    }
}
