import SwiftUI

struct StrengthExperienceView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private var choices: [OnboardingChoiceList<StrengthExperience>.Choice] {
        StrengthExperience.allCases.map {
            .init(value: $0, label: $0.displayName, subtitle: $0.subtitle, icon: $0.icon)
        }
    }

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Strength",
            iconColor: .biteRedDeep,
            title: "Strength training experience",
            subtitle: "Bite will scale rest timers and exercise suggestions to your level."
        ) {
            OnboardingChoiceList(
                choices: choices,
                selection: Binding(
                    get: { vm.strengthExperience },
                    set: { vm.strengthExperience = $0 ?? .beginner }
                )
            )
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        StrengthExperienceView(vm: OnboardingViewModel(), onContinue: {})
    }
}
