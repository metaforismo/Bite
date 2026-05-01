import SwiftUI

struct DietaryPreferencesView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private var options: [OnboardingChipPicker<DietaryPreference>.Option] {
        DietaryPreference.v2Choices.map {
            .init(value: $0, label: $0.displayName, icon: $0.icon)
        }
    }

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "leaf.fill",
            iconColor: .biteFiber,
            title: "How do you eat?",
            subtitle: "Pick everything that applies. Bite tailors meal suggestions and nutrition coaching to your style.",
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            ScrollView(showsIndicators: false) {
                OnboardingChipPicker(
                    options: options,
                    selection: $vm.dietaryPreferenceSet
                )
            }
            .frame(maxHeight: 380)
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        DietaryPreferencesView(vm: OnboardingViewModel(), onContinue: {})
    }
}
