import SwiftUI

struct HeightInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "ruler",
            iconColor: .biteBlue,
            title: "How tall are you?",
            subtitle: "Used to estimate your basal metabolic rate."
        ) {
            OnboardingNumberCard(
                value: $vm.heightCm,
                placeholder: "170",
                unit: "cm",
                allowsDecimal: false,
                decrement: { adjustHeight(by: -1) },
                increment: { adjustHeight(by: 1) }
            )
        } primaryAction: {
            onContinue()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func adjustHeight(by amount: Double) {
        let current = OnboardingViewModel.parseDecimal(vm.heightCm) ?? 170
        let newValue = max(100, min(250, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.heightCm = String(format: "%.0f", newValue)
        }
    }
}

#Preview {
    HeightInputView(vm: OnboardingViewModel(), onContinue: {})
}
