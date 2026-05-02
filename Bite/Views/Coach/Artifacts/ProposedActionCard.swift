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
    @State private var editing: Bool = false
    @State private var correctionText: String = ""
    @FocusState private var correctionFocused: Bool

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
                if editing {
                    inlineCorrectionEditor
                } else {
                    actionFooter
                }
            case .confirmed:
                confirmedFooter
            case .discarded:
                EmptyView()
            }
        }
        .onAppear(perform: decodePayload)
        .onChange(of: artifact.version) { _, _ in decodePayload() }
        .animation(BiteMotion.routeSheet, value: phase)
        .animation(BiteMotion.routeSheet, value: editing)
    }

    /// Inline TextEditor for correcting a proposed entry. Tapping
    /// "Re-estimate" calls the Coach with a structured correction
    /// prompt referencing the artifact id; cancel returns to the
    /// action footer without sending anything.
    private var inlineCorrectionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT SHOULD CHANGE?")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.biteInkFaint)

            ZStack(alignment: .topLeading) {
                if correctionText.isEmpty {
                    Text("e.g. \"actually 300g\", \"half a portion\", \"whole milk\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $correctionText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 56, maxHeight: 96)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .focused($correctionFocused)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black.opacity(0.07), lineWidth: 1))

            HStack(spacing: 8) {
                Button(action: cancelEdit) {
                    Text("Cancel")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
                .buttonStyle(.plain)

                Button(action: submitCorrection) {
                    Text("Re-estimate")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(.biteInk, in: Capsule())
                .buttonStyle(.plain)
                .disabled(correctionText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(correctionText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
        .onAppear { correctionFocused = true }
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
        editing = true
    }

    private func cancelEdit() {
        BiteHaptics.selection()
        correctionText = ""
        editing = false
    }

    private func submitCorrection() {
        let text = correctionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        BiteHaptics.impact(.light)
        // Forward to Coach via prefilled prompt referencing the artifact id.
        // The worker's correctFoodEntry tool re-emits the same artifact id
        // at version+1, which `decodePayload` automatically remirrors.
        router.prefilledChatPrompt = "correct food/\(artifact.id.uuidString.lowercased()): \(text)"
        correctionText = ""
        editing = false
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
