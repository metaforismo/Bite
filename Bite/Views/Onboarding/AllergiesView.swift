import SwiftUI

struct AllergiesView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private static let presets: [(label: String, icon: String)] = [
        ("Peanuts", "circle.fill"),
        ("Tree nuts", "tree.fill"),
        ("Shellfish", "fish.fill"),
        ("Eggs", "circle.dotted"),
        ("Soy", "leaf.fill"),
        ("Wheat", "circle.hexagongrid.fill"),
        ("Dairy", "drop.fill"),
        ("Sesame", "circle.dashed")
    ]

    private var options: [OnboardingChipPicker<String>.Option] {
        Self.presets.map { .init(value: $0.label, label: $0.label, icon: $0.icon) }
    }

    @State private var customAllergy: String = ""

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "exclamationmark.shield.fill",
            iconColor: .biteWarning,
            title: "Any allergies or intolerances?",
            subtitle: "Bite will avoid these in any meal suggestion or recipe. Skip if none apply.",
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    OnboardingChipPicker(
                        options: options,
                        selection: $vm.allergiesSet
                    )

                    HStack(spacing: 8) {
                        TextField("Other (e.g., kiwi)", text: $customAllergy)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.78))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                            }

                        Button {
                            let trimmed = customAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            vm.allergiesSet.insert(trimmed)
                            customAllergy = ""
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.biteRed))
                        }
                        .buttonStyle(.plain)
                        .disabled(customAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .frame(maxHeight: 420)
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        AllergiesView(vm: OnboardingViewModel(), onContinue: {})
    }
}
