import SwiftUI

struct ActivityStatusBaselineView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private var choices: [OnboardingChoiceList<ActivityStatusKind>.Choice] {
        ActivityStatusKind.allCases.map {
            .init(value: $0, label: $0.displayName, subtitle: $0.subtitle, icon: $0.icon)
        }
    }

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "bolt.fill",
            iconColor: .biteRingRecovery,
            title: "How are you starting?",
            subtitle: "Bite adapts coaching when you're sick, injured, or taking a break. You can change this anytime."
        ) {
            OnboardingChoiceList(
                choices: choices,
                selection: Binding(
                    get: { vm.activityStatusBaseline },
                    set: { vm.activityStatusBaseline = $0 ?? .active }
                )
            )
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        ActivityStatusBaselineView(vm: OnboardingViewModel(), onContinue: {})
    }
}
