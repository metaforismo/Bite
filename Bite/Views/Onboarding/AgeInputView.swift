import SwiftUI

struct AgeInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "calendar",
            iconColor: .biteBlue,
            title: "How old are you?",
            subtitle: "Used to estimate your basal metabolic rate."
        ) {
            OnboardingNumberCard(
                value: $vm.age,
                placeholder: "25",
                unit: "years",
                allowsDecimal: false,
                decrement: { adjustAge(by: -1) },
                increment: { adjustAge(by: 1) }
            )
        } primaryAction: {
            onContinue()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func adjustAge(by amount: Int) {
        let current = Int(vm.age) ?? 25
        let newValue = max(16, min(100, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.age = "\(newValue)"
        }
    }
}

#Preview {
    AgeInputView(vm: OnboardingViewModel(), onContinue: {})
}
