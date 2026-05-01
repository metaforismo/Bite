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
    var prefilledChatPrompt: String?
    var modalSheet: ModalSheet?
    var activeWorkoutSession: WorkoutSessionContext?

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
        prefilledChatPrompt = prefill
        withAnimation(BiteMotion.routeSheet) { route = .chat }
        if thenPlus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(BiteMotion.plusSheet) { plusSheetOpen = true }
            }
        }
    }

    func openFiles() {
        drawerOpen = false
        withAnimation(BiteMotion.routeSheet) { route = .files }
    }

    func closeOverlay() {
        withAnimation(BiteMotion.routeSheet) { route = .home }
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

    func openModal(_ sheet: ModalSheet) {
        withAnimation(BiteMotion.routeSheet) { modalSheet = sheet }
    }

    func closeModal() {
        withAnimation(BiteMotion.routeSheet) { modalSheet = nil }
    }
}
