import SwiftUI

enum BiteRoute: String, CaseIterable, Hashable {
    case home
    case chat
    case files

    /// Routes that hide the floating AskBite pill + bottom tab pill — these
    /// are immersive and own their own bottom UI (composer, files toolbar).
    var hidesAskPill: Bool {
        self != .home
    }
}

enum HomeTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case journal
    case fitness
    case biology

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:    return "Home"
        case .journal: return "Journal"
        case .fitness: return "Fitness"
        case .biology: return "Biology"
        }
    }

    var systemImage: String {
        switch self {
        case .home:    return "house.fill"
        case .journal: return "book.closed.fill"
        case .fitness: return "figure.run"
        case .biology: return "heart.fill"
        }
    }
}

@MainActor
@Observable
final class BiteRouter {
    var route: BiteRoute = .home
    var homeTab: HomeTab = .home
    var drawerOpen: Bool = false
    var plusSheetOpen: Bool = false
    var filesSheetOpen: Bool = false
    var logSheetOpen: Bool = false
    var healthRecordsSheetOpen: Bool = false
    var prefilledChatPrompt: String?
    var requestedCoachThread: CoachThread?
    var newChatRequestID = UUID()
    /// When set, CoachView immediately sends this message in a new turn
    /// instead of waiting for the user to tap Send. Used by file uploads
    /// to kick off analysis automatically. Cleared after consumption.
    var autoSendChatMessage: String?
    var modalSheet: ModalSheet?
    var activeWorkoutSession: WorkoutSessionContext?

    /// One-shot id consumed by `MealsTimelineCard` / similar lists to flash a
    /// ring-pulse highlight on a freshly-mirrored entry. Cleared after consumption.
    var pendingHighlightEntryId: UUID?

    /// Last receipt from a Coach-driven mutation. The chat surfaces a
    /// "View in Today" chip from this; consumed views can read the entry id.
    var lastToolReceipt: CoachToolReceipt?

    func recordToolReceipt(_ receipt: CoachToolReceipt) {
        lastToolReceipt = receipt
    }

    /// Close the chat, switch to the receipt's affected tab, and stage the
    /// entry id for highlight. Used when the user taps "View in Today".
    func revealLastReceipt() {
        guard let receipt = lastToolReceipt else { return }
        if let tab = receipt.affectedTab { homeTab = tab }
        pendingHighlightEntryId = receipt.entryId
        closeOverlay()
    }

    func startWorkoutSession(_ ctx: WorkoutSessionContext) {
        withAnimation(BiteMotion.routeSheet) {
            activeWorkoutSession = ctx
        }
    }

    func endWorkoutSession() {
        withAnimation(BiteMotion.routeSheet) {
            activeWorkoutSession = nil
        }
    }

    func openChat(prefill: String? = nil, thenPlus: Bool = false) {
        requestedCoachThread = nil
        prefilledChatPrompt = prefill
        withAnimation(BiteMotion.chatMorph) { route = .chat }
        if thenPlus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(BiteMotion.plusSheet) { plusSheetOpen = true }
            }
        }
    }

    func openChatThread(_ thread: CoachThread) {
        requestedCoachThread = thread
        prefilledChatPrompt = nil
        drawerOpen = false
        withAnimation(BiteMotion.chatMorph) { route = .chat }
    }

    func startNewChat() {
        requestedCoachThread = nil
        prefilledChatPrompt = nil
        newChatRequestID = UUID()
        drawerOpen = false
        withAnimation(BiteMotion.chatMorph) { route = .chat }
    }

    func openFiles() {
        drawerOpen = false
        filesSheetOpen = true
    }

    func closeFiles() {
        filesSheetOpen = false
    }

    func closeOverlay() {
        let animation: Animation = (route == .chat) ? BiteMotion.chatMorph : BiteMotion.routeSheet
        withAnimation(animation) { route = .home }
    }

    func toggleDrawer() {
        withAnimation(BiteMotion.drawerSlide) { drawerOpen.toggle() }
    }

    func openPlusSheet() {
        withAnimation(BiteMotion.plusSheet) { plusSheetOpen = true }
    }

    func closePlusSheet() {
        withAnimation(BiteMotion.plusSheet) { plusSheetOpen = false }
    }

    /// Unified entry point for all "log something" actions, surfacing the
    /// existing modal sheets (hydration/caffeine/cycle/activity/smartAlarm)
    /// + Coach handoff for food, plus a Files shortcut. Replaces the
    /// `openChat(thenPlus: true)` workaround on the bottom-pill `+` button.
    func openLogSheet() {
        withAnimation(BiteMotion.plusSheet) { logSheetOpen = true }
    }

    func closeLogSheet() {
        withAnimation(BiteMotion.plusSheet) { logSheetOpen = false }
    }

    func openHealthRecords() {
        drawerOpen = false
        healthRecordsSheetOpen = true
    }

    func closeHealthRecords() {
        healthRecordsSheetOpen = false
    }

    func openModal(_ sheet: ModalSheet) {
        withAnimation(BiteMotion.routeSheet) { modalSheet = sheet }
    }

    func closeModal() {
        withAnimation(BiteMotion.routeSheet) { modalSheet = nil }
    }
}
