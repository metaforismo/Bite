import SwiftUI

/// Multi-select chip grid used by Dietary Preferences, Allergies, Supplements,
/// Symptoms, and Journal Tags pages. Two-column flow with biteRed selection state.
struct OnboardingChipPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        let icon: String?
        var id: Value { value }

        init(value: Value, label: String, icon: String? = nil) {
            self.value = value
            self.label = label
            self.icon = icon
        }
    }

    let options: [Option]
    @Binding var selection: Set<Value>
    var columns: Int = 2

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
        LazyVGrid(columns: grid, spacing: 10) {
            ForEach(options) { option in
                let isSelected = selection.contains(option.value)
                Button {
                    BiteHaptics.selection()
                    withAnimation(BiteMotion.chipSelect) {
                        if isSelected {
                            selection.remove(option.value)
                        } else {
                            selection.insert(option.value)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if let icon = option.icon {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : .biteInkMuted)
                        }
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : .biteInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Color.biteRed : Color.white.opacity(0.78))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.biteRed : Color.black.opacity(0.07),
                                lineWidth: 1
                            )
                    }
                    .scaleEffect(isSelected ? 1.03 : 1)
                    .shadow(color: isSelected ? Color.biteRed.opacity(0.22) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Single-select variant — same visuals, exclusive selection.
struct OnboardingSingleChipPicker<Value: Hashable>: View {
    let options: [OnboardingChipPicker<Value>.Option]
    @Binding var selection: Value?
    var columns: Int = 2

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
        LazyVGrid(columns: grid, spacing: 10) {
            ForEach(options) { option in
                let isSelected = selection == option.value
                Button {
                    BiteHaptics.selection()
                    withAnimation(BiteMotion.chipSelect) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: 8) {
                        if let icon = option.icon {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : .biteInkMuted)
                        }
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : .biteInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Color.biteRed : Color.white.opacity(0.78))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.biteRed : Color.black.opacity(0.07),
                                lineWidth: 1
                            )
                    }
                    .scaleEffect(isSelected ? 1.03 : 1)
                    .shadow(color: isSelected ? Color.biteRed.opacity(0.22) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Vertical card list (one per row) — used for choices that benefit from
/// description text (Activity Status, Strength Experience, Personality).
struct OnboardingChoiceList<Value: Hashable>: View {
    struct Choice: Identifiable {
        let value: Value
        let label: String
        let subtitle: String?
        let icon: String
        var id: Value { value }
    }

    let choices: [Choice]
    @Binding var selection: Value?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(choices) { choice in
                let isSelected = selection == choice.value
                Button {
                    BiteHaptics.selection()
                    withAnimation(BiteMotion.chipSelect) {
                        selection = choice.value
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: choice.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.biteRed : .biteInkMuted)
                            .frame(width: 32, height: 32)
                            .background {
                                Circle().fill(
                                    isSelected ? Color.biteRedTint : Color.black.opacity(0.04)
                                )
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(choice.label)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.biteInk)
                            if let subtitle = choice.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.biteInkMuted)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.biteRed)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? Color.biteRedTint.opacity(0.45) : Color.white.opacity(0.78))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.biteRed : Color.black.opacity(0.07),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .shadow(
                        color: isSelected ? Color.biteRed.opacity(0.18) : .clear,
                        radius: 10, x: 0, y: 4
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
