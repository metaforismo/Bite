import SwiftUI

struct WeightInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "scalemass",
            iconColor: .biteBlue,
            title: "How much do you weigh?",
            subtitle: "Used to estimate your basal metabolic rate."
        ) {
            OnboardingNumberCard(
                value: $vm.weightKg,
                placeholder: "70",
                unit: "kg",
                allowsDecimal: true,
                decrement: { adjustWeight(by: -0.5) },
                increment: { adjustWeight(by: 0.5) }
            )
        } primaryAction: {
            onContinue()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func adjustWeight(by amount: Double) {
        let current = OnboardingViewModel.parseDecimal(vm.weightKg) ?? 70
        let newValue = max(30, min(300, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.weightKg = String(format: "%.1f", newValue)
        }
    }
}

#Preview {
    WeightInputView(vm: OnboardingViewModel(), onContinue: {})
}
