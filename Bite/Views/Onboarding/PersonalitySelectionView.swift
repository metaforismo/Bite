import SwiftUI

struct PersonalitySelectionView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private var choices: [OnboardingChoiceList<CoachPersonality>.Choice] {
        CoachPersonality.allCases.map {
            .init(value: $0, label: $0.displayName, subtitle: $0.subtitle, icon: $0.icon)
        }
    }

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Personality",
            iconColor: .biteRedSoft,
            title: "Coach personality",
            subtitle: "How do you want Bite to talk to you? You can change this anytime in Settings."
        ) {
            OnboardingChoiceList(
                choices: choices,
                selection: Binding(
                    get: { vm.coachPersonality },
                    set: { vm.coachPersonality = $0 ?? .friend }
                )
            )
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        PersonalitySelectionView(vm: OnboardingViewModel(), onContinue: {})
    }
}
