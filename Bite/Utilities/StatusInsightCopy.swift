import Foundation

/// Local copy lookup so the Today insight can swap title/body when the user's
/// activity status is non-active, without round-tripping to the worker.
/// Future server-baked insights (per `/v1/today`) override this when present.
enum StatusInsightCopy {
    struct Copy {
        let title: String
        let message: String
        let ctaPrefill: String
    }

    static func copy(for kind: ActivityStatusKind, daysActive: Int) -> Copy {
        switch kind {
        case .active:
            return Copy(
                title: "Set up your morning signal",
                message: "Bite generates your overnight summary once your account is connected. Tap to ask Bite anything.",
                ctaPrefill: "Give me my morning analysis"
            )
        case .sick:
            return Copy(
                title: "Recover smart",
                message: "You've been feeling off for \(daysActive) day\(daysActive == 1 ? "" : "s"). Sleep, fluids, and gentle movement come first today.",
                ctaPrefill: "I'm sick — what should I prioritize today?"
            )
        case .injured where daysActive >= 7:
            return Copy(
                title: "Rest up and reset",
                message: "Day \(daysActive) of recovery. Bite shifted your training plan toward mobility and easy aerobic — let's protect the long game.",
                ctaPrefill: "I'm \(daysActive) days into injury recovery. What's the smart move?"
            )
        case .injured:
            return Copy(
                title: "Easy day, by design",
                message: "Day \(daysActive) of recovery. Lighter loads, more sleep, same focus on protein. Bite will check in.",
                ctaPrefill: "I'm injured — adjust today's plan."
            )
        case .onBreak:
            return Copy(
                title: "Take it easy",
                message: "You're on a break. Bite kept your goals warm — we'll pick up where you left off when you're ready.",
                ctaPrefill: "I'm on a break. What should I think about during this time?"
            )
        }
    }
}
