import Foundation

/// Outcome of a Coach tool action that mutated the user's local state.
///
/// Surfaced to the chat UI so it can show a "View in [tab]" navigation chip
/// after the user confirms a proposed action.
struct CoachToolReceipt: Equatable, Sendable {
    enum Kind: String, Sendable {
        case foodAdded
        case foodCorrected
        case foodDiscarded
        case drinkAdded
        case activityStatusChanged
        case cycleEntryAdded
        case weightLogged
        case workoutCompleted
    }

    let kind: Kind
    let entryId: UUID?
    let affectedTab: HomeTab?
    let summary: String
    let timestamp: Date

    init(
        kind: Kind,
        entryId: UUID? = nil,
        affectedTab: HomeTab? = .home,
        summary: String,
        timestamp: Date = Date()
    ) {
        self.kind = kind
        self.entryId = entryId
        self.affectedTab = affectedTab
        self.summary = summary
        self.timestamp = timestamp
    }
}
