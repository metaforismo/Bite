import SwiftUI

struct GenderView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Gender",
            iconColor: .biteBlue,
            title: "What's your gender?",
            subtitle: "Used to estimate your daily calorie need.",
            primaryActionDisabled: vm.gender == nil
        ) {
            VStack(spacing: 10) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    GenderRow(
                        gender: gender,
                        isSelected: vm.gender == gender
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.updateGender(gender)
                        }
                    }
                }
            }
        } primaryAction: {
            onContinue()
        }
    }
}

/// One row of the gender picker. Extracted into a separate view so each row
/// owns its own redraw scope — selection toggling on one row no longer
/// thrashes the others — and so a single Button covers the entire row with
/// `.contentShape(Rectangle())`, guaranteeing the full 56pt height is
/// tappable. (The previous custom layout in `GenderView` registered taps
/// only on the visible content, which is why "Male", "Other", and "Prefer
/// not to say" appeared unselectable.)
private struct GenderRow: View {
    let gender: Gender
    let isSelected: Bool
    let onTap: () -> Void

    private var icon: String {
        switch gender {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .other: return "person.fill.questionmark"
        case .preferNotToSay: return "hand.raised.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.biteRed : .secondary)

                Text(gender.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.biteRed : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.biteRed)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.biteRed.opacity(0.15) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.biteRed : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GenderView(vm: OnboardingViewModel(), onContinue: {})
}
