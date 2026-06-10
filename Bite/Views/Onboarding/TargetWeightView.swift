import SwiftUI

struct TargetWeightView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "target",
            iconColor: .biteRed,
            title: "Target weight",
            subtitle: "What weight would you like to reach?"
        ) {
            OnboardingNumberCard(
                value: $vm.targetWeightKg,
                placeholder: "70",
                unit: "kg",
                allowsDecimal: true,
                decrement: { adjustWeight(by: -1) },
                increment: { adjustWeight(by: 1) },
                footnote: targetDeltaText
            )
        } primaryAction: {
            onContinue()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var targetDeltaText: String? {
        guard let currentWeight = OnboardingViewModel.parseDecimal(vm.weightKg),
              let targetWeight = OnboardingViewModel.parseDecimal(vm.targetWeightKg),
              currentWeight > 0,
              targetWeight > 0 else { return nil }
        let diff = currentWeight - targetWeight
        if diff > 0 { return "Lose \(String(format: "%.1f", abs(diff))) kg" }
        if diff < 0 { return "Gain \(String(format: "%.1f", abs(diff))) kg" }
        return "Maintain weight"
    }

    private func adjustWeight(by amount: Double) {
        let current = OnboardingViewModel.parseDecimal(vm.targetWeightKg) ?? 70
        let newValue = max(30, min(300, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.targetWeightKg = String(format: "%.0f", newValue)
        }
    }
}

#Preview {
    TargetWeightView(vm: OnboardingViewModel(), onContinue: {})
}
