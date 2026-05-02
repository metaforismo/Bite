import Foundation

/// Deep links emitted by the BiteWidgets extension via `widgetURL(...)` —
/// the main app routes them to the right tab / modal on launch.
enum BiteDeepLink: Hashable {
    case today
    case journal
    case fitness
    case biology
    case hydration
    case dailyReview

    init?(url: URL) {
        guard url.scheme == "bite" else { return nil }
        switch url.host {
        case "today":        self = .today
        case "journal":      self = .journal
        case "fitness":      self = .fitness
        case "biology":      self = .biology
        case "hydration":    self = .hydration
        case "daily-review": self = .dailyReview
        default: return nil
        }
    }
}
