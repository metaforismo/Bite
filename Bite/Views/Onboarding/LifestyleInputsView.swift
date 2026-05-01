import SwiftUI

struct LifestyleInputsView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private static let supplementOptions: [(label: String, icon: String)] = [
        ("Multivitamin", "pills.fill"),
        ("Vitamin D", "sun.max.fill"),
        ("Omega-3", "fish.fill"),
        ("Creatine", "bolt.fill"),
        ("Magnesium", "leaf.fill"),
        ("Protein", "p.circle.fill"),
        ("Probiotic", "circle.dotted"),
        ("Other", "ellipsis.circle.fill")
    ]

    private var smokingChoices: [OnboardingChoiceList<SmokingStatus>.Choice] {
        SmokingStatus.allCases.map { .init(value: $0, label: $0.displayName, subtitle: nil, icon: smokingIcon($0)) }
    }

    private var alcoholChoices: [OnboardingChoiceList<AlcoholFrequency>.Choice] {
        AlcoholFrequency.allCases.map { .init(value: $0, label: $0.displayName, subtitle: nil, icon: alcoholIcon($0)) }
    }

    private var supplementOptions: [OnboardingChipPicker<String>.Option] {
        Self.supplementOptions.map { .init(value: $0.label, label: $0.label, icon: $0.icon) }
    }

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Lifestyle",
            iconColor: .bitePurple,
            title: "Lifestyle inputs",
            subtitle: "These help Bite estimate your biological age and shape recovery insights. Skip anything you'd rather not share.",
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader("Smoking")
                    OnboardingChoiceList(
                        choices: smokingChoices,
                        selection: $vm.smokingStatus
                    )

                    sectionHeader("Alcohol")
                    OnboardingChoiceList(
                        choices: alcoholChoices,
                        selection: $vm.alcoholFrequency
                    )

                    sectionHeader("Supplements")
                    OnboardingChipPicker(
                        options: supplementOptions,
                        selection: $vm.supplementsSet
                    )
                }
            }
            .frame(maxHeight: 420)
        } primaryAction: { onContinue() }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.biteInkMuted)
            .padding(.top, 4)
    }

    private func smokingIcon(_ s: SmokingStatus) -> String {
        switch s {
        case .never: return "checkmark.shield.fill"
        case .former: return "clock.arrow.circlepath"
        case .current: return "smoke.fill"
        }
    }

    private func alcoholIcon(_ a: AlcoholFrequency) -> String {
        switch a {
        case .none: return "checkmark.shield.fill"
        case .occasional: return "wineglass"
        case .weekly: return "wineglass.fill"
        case .daily: return "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        LifestyleInputsView(vm: OnboardingViewModel(), onContinue: {})
    }
}
