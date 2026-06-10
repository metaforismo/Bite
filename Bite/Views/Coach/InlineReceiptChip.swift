import SwiftUI

/// Compact "X added · View in [tab]" chip surfaced inline in the Coach
/// chat after a non-food tool_result mutates local SwiftData. Tap
/// closes the chat and switches to the affected tab.
struct InlineReceiptChip: View {
    let receipt: CoachToolReceipt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tint, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(receipt.summary)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .lineLimit(1)
                    if let tab = receipt.affectedTab {
                        Text("View in \(tab.displayName)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch receipt.kind {
        case .foodAdded, .foodCorrected, .foodDiscarded: return "fork.knife"
        case .drinkAdded:           return "drop.fill"
        case .activityStatusChanged: return "figure.run"
        case .cycleEntryAdded:       return "calendar.badge.clock"
        case .weightLogged:          return "scalemass.fill"
        case .workoutCompleted:      return "checkmark"
        }
    }

    private var tint: Color {
        switch receipt.kind {
        case .foodAdded, .foodCorrected: return .biteRed
        case .foodDiscarded:             return .biteInkFaint
        case .drinkAdded:                return .biteHydration
        case .activityStatusChanged:     return .biteRingRecovery
        case .cycleEntryAdded:           return .biteRedSoft
        case .weightLogged:              return .biteFiber
        case .workoutCompleted:          return .biteRingRecovery
        }
    }
}
