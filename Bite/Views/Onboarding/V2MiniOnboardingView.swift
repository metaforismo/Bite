import SwiftUI

/// Slim, fixed-sequence onboarding for users upgrading from V1 — captures only
/// the new V2 dimensions (hydration goal, caffeine limit, sleep target, strength
/// experience, lifestyle inputs, personality). On completion, merges the V2 fields
/// into the existing UserProfile.
struct V2MiniOnboardingView: View {
    @State private var vm: OnboardingViewModel
    @State private var step: Int = 0
    let onDone: (UserProfile) -> Void

    private let pages: [OnboardingPage] = [
        .hydrationGoal,
        .caffeineLimit,
        .sleepTarget,
        .strengthExperience,
        .lifestyleInputs,
        .personality,
    ]

    init(profile: UserProfile, onDone: @escaping (UserProfile) -> Void) {
        let vm = OnboardingViewModel()
        // Pre-populate with the existing profile so users see their current
        // values rather than defaults.
        vm.hydrationGoalML = profile.hydrationGoalML
        vm.caffeineLimitMg = profile.caffeineLimitMg
        vm.sleepTargetWakeTime = profile.sleepTargetWakeTime
        vm.sleepTargetHours = profile.sleepTargetHours
        vm.strengthExperience = profile.strengthExperience
        vm.smokingStatus = profile.smokingStatus
        vm.alcoholFrequency = profile.alcoholFrequency
        vm.supplementsSet = Set(profile.supplements)
        vm.coachPersonality = profile.coachPersonality
        self._vm = State(initialValue: vm)
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            BiteGradientBackground(style: .today)

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                pageContent
                    .frame(maxHeight: .infinity)
                    .id(step)

                OnboardingProgressBar(
                    totalPages: pages.count,
                    currentPage: step
                )
                .padding(.bottom, 16)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                if step > 0 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        step -= 1
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)

            Spacer()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch pages[min(step, pages.count - 1)] {
            case .hydrationGoal:
                HydrationGoalView(vm: vm) { advance() }
            case .caffeineLimit:
                CaffeineLimitView(vm: vm) { advance() }
            case .sleepTarget:
                SleepTargetView(vm: vm) { advance() }
            case .strengthExperience:
                StrengthExperienceView(vm: vm) { advance() }
            case .lifestyleInputs:
                LifestyleInputsView(vm: vm) { advance() }
            case .personality:
                PersonalitySelectionView(vm: vm) { complete() }
            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func advance() {
        if step < pages.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                step += 1
            }
        } else {
            complete()
        }
    }

    private func complete() {
        var profile = StorageService.shared.loadProfile()
        profile.hydrationGoalML = vm.hydrationGoalML
        profile.caffeineLimitMg = vm.caffeineLimitMg
        profile.sleepTargetWakeTime = vm.sleepTargetWakeTime
        profile.sleepTargetHours = vm.sleepTargetHours
        profile.strengthExperience = vm.strengthExperience
        profile.smokingStatus = vm.smokingStatus
        profile.alcoholFrequency = vm.alcoholFrequency
        profile.supplements = Array(vm.supplementsSet).sorted()
        profile.coachPersonality = vm.coachPersonality
        StorageService.shared.saveProfile(profile)
        onDone(profile)
    }
}
