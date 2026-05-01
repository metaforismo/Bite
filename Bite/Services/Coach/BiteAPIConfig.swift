import Foundation

enum BiteAPIConfig {
    /// Resolved at runtime from Info.plist key `BITE_API_BASE_URL`.
    /// Falls back to `http://localhost:8787` for local Wrangler dev.
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "BITE_API_BASE_URL") as? String,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:8787")!
    }
}
