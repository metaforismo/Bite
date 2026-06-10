import SwiftUI

/// Wraps an artifact (today: only `food_cart`) with the agentic
/// **Confirm / Edit / Discard** affordances that drive `CoachToolDispatcher`.
///
/// The artifact body itself is rendered by the existing specialized card
/// (e.g. `FoodCartCard`); this view adds the action footer + handles the
/// confirmed/discarded local state so the chat shows clear feedback.
@available(iOS 26.0, *)
struct ProposedActionCard: View {
    let artifact: ArtifactMessage

    @Environment(BiteRouter.self) private var router
    @State private var phase: Phase = .pending
    @State private var receipt: CoachToolReceipt?
    @State private var decoded: FoodCartPayload?

    private enum Phase: Equatable {
        case pending
        case confirmed
        case discarded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FoodCartCard(artifact: artifact)
                .opacity(phase == .discarded ? 0.45 : 1)
                .overlay(alignment: .topTrailing) {
                    if phase == .discarded {
                        Text("Discarded")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.3)
                            .foregroundStyle(.biteInkFaint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white, in: Capsule())
                            .padding(10)
                    }
                }

            switch phase {
            case .pending:
                actionFooter
            case .confirmed:
                confirmedFooter
            case .discarded:
                EmptyView()
            }
        }
        .onAppear(perform: decodePayload)
        .onChange(of: artifact.version) { _, _ in decodePayload() }
        .animation(BiteMotion.routeSheet, value: phase)
    }

    // MARK: - Footers

    private var actionFooter: some View {
        HStack(spacing: 8) {
            Button(action: discard) {
                Text("Discard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
            .buttonStyle(.plain)

            Button(action: edit) {
                Text("Edit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
            .buttonStyle(.plain)

            Button(action: confirm) {
                Text("Save")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .background(.biteInk, in: Capsule())
            .buttonStyle(.plain)
        }
    }

    private var confirmedFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.biteRingRecovery)
                .font(.system(size: 16, weight: .bold))
            Text(receipt?.summary ?? "Saved")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
            Spacer()
            Button(action: viewInTab) {
                HStack(spacing: 4) {
                    Text("View in Today")
                        .font(.system(size: 12.5, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.biteInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func decodePayload() {
        guard let data = try? JSONDecoder.bite.decode(FoodCartPayload.self, from: artifact.payloadJSON) else { return }
        decoded = data

        // If the model already mirrored this entry locally (because the user
        // confirmed an earlier version and a corrected version arrived), keep
        // the confirmed phase but refresh the summary so it reflects the new
        // macros.
        if phase == .confirmed, let receipt = receipt, let entryId = receipt.entryId {
            CoachToolDispatcher.shared.mirrorFoodEntry(data, originatingArtifactId: entryId)
            self.receipt = CoachToolReceipt(
                kind: .foodCorrected,
                entryId: entryId,
                affectedTab: .home,
                summary: "Updated · \(data.kcal) kcal"
            )
        }
    }

    private func confirm() {
        guard let payload = decoded else { return }
        BiteHaptics.impact(.light)
        let result = CoachToolDispatcher.shared.mirrorFoodEntry(payload, originatingArtifactId: artifact.id)
        receipt = result
        router.recordToolReceipt(result)
        phase = .confirmed
    }

    private func edit() {
        BiteHaptics.selection()
        // Pre-fill the composer with a correction prompt the user can finish.
        // The Coach call to `correctFoodEntry` will re-emit the same artifact
        // at version+1, which `decodePayload` re-mirrors automatically.
        router.prefilledChatPrompt = "Correct: "
    }

    private func discard() {
        BiteHaptics.impact(.light)
        if let entryId = receipt?.entryId ?? (phase == .confirmed ? artifact.id : nil) {
            CoachToolDispatcher.shared.discardMirroredFood(entryId: entryId)
        }
        phase = .discarded
    }

    private func viewInTab() {
        router.revealLastReceipt()
    }
}
