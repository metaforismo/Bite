import SwiftUI

struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()

    var onComplete: (UserProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            BiteTopBar(
                onBack: vm.currentPage > 0 ? { vm.previousPage() } : nil
            ) {
                OnboardingProgressBar(
                    totalPages: vm.totalPages,
                    currentPage: vm.currentPage
                )
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)

            // Top bar bottom edge is at `safeAreaTop + 12 + 56`. The 150pt
            // reserved-zone line lives at `safeAreaTop + 100`, so add the
            // missing 32pt before page content begins.
            pageContent
                .frame(maxHeight: .infinity)
                .padding(.top, 32)
                .id(vm.currentPage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            BiteGradientBackground(style: .today)
                .overlay {
                    // Subtle moving grain to keep the static gradient feeling alive.
                    DriftingGlow()
                        .allowsHitTesting(false)
                        .opacity(0.55)
                }
                .ignoresSafeArea()
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Slow-moving radial highlight behind the entire onboarding flow. Pure
    /// decoration — adds warmth and a sense of life without taxing perf.
    private struct DriftingGlow: View {
        @State private var animate = false
        var body: some View {
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.biteRedSoft.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: max(geo.size.width, 240)
                        )
                    )
                    .frame(width: 360, height: 360)
                    .position(
                        x: animate ? geo.size.width * 0.7 : geo.size.width * 0.3,
                        y: animate ? geo.size.height * 0.25 : geo.size.height * 0.15
                    )
                    .blur(radius: 30)
                    .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: animate)
                    .onAppear { animate = true }
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch vm.currentPageIdentifier {
            case .welcome:
                WelcomeView { vm.nextPage() }
            case .healthKit:
                HealthKitView(
                    onContinue: { vm.nextPage() },
                    onAuthorized: {
                        vm.healthKitAuthorized = true
                        Task { await vm.autoPopulateFromHealthKit() }
                    }
                )
            case .notifications:
                NotificationsPermissionView { vm.nextPage() }
            case .microphone:
                MicrophonePermissionView { vm.nextPage() }
            case .camera:
                CameraPermissionView { vm.nextPage() }
            case .name:
                NameInputPage(vm: vm) { vm.nextPage() }
            case .gender:
                GenderView(vm: vm) { vm.nextPage() }
            case .age:
                AgeInputView(vm: vm) { vm.nextPage() }
            case .height:
                HeightInputView(vm: vm) { vm.nextPage() }
            case .weight:
                WeightInputView(vm: vm) { vm.nextPage() }
            case .targetWeight:
                TargetWeightView(vm: vm) { vm.nextPage() }
            case .activityLevel:
                ActivityLevelView(vm: vm) { vm.nextPage() }
            case .dietaryPreferences:
                DietaryPreferencesView(vm: vm) { vm.nextPage() }
            case .allergies:
                AllergiesView(vm: vm) { vm.nextPage() }
            case .hydrationGoal:
                HydrationGoalView(vm: vm) { vm.nextPage() }
            case .caffeineLimit:
                CaffeineLimitView(vm: vm) { vm.nextPage() }
            case .sleepTarget:
                SleepTargetView(vm: vm) { vm.nextPage() }
            case .strengthExperience:
                StrengthExperienceView(vm: vm) { vm.nextPage() }
            case .cycleTracking:
                CycleTrackingOptInView(vm: vm) { vm.nextPage() }
            case .activityStatusBaseline:
                ActivityStatusBaselineView(vm: vm) { vm.nextPage() }
            case .lifestyleInputs:
                LifestyleInputsView(vm: vm) { vm.nextPage() }
            case .calorieBias:
                CalorieBiasView(vm: vm) { vm.nextPage() }
            case .journalTagsIntro:
                JournalTagsIntroView { vm.nextPage() }
            case .personality:
                PersonalitySelectionView(vm: vm) { vm.nextPage() }
            case .widgetsTeaser:
                WidgetsTeaserView { vm.nextPage() }
            case .goalSummary:
                GoalSummaryView(vm: vm) {
                    Task {
                        let profile = await vm.completeOnboarding()
                        onComplete(profile)
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .push(from: .trailing).combined(with: .opacity),
            removal: .push(from: .leading).combined(with: .opacity)
        ))
        .animation(BiteMotion.onboardingPage, value: vm.currentPage)
    }
}

// MARK: - Name Input Page (V1 had this inline; extracted so the orchestrator stays thin)

private struct NameInputPage: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "person.crop.circle.fill",
            iconColor: .biteBlue,
            title: "What's your name?",
            subtitle: "Bite uses your name to personalize coaching.",
            primaryActionDisabled: !vm.isNameValid
        ) {
            TextField("Your name", text: $vm.name)
                .font(.system(size: 18, weight: .semibold))
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                }
                .focused($nameFieldFocused)
                .submitLabel(.continue)
                .onSubmit {
                    if vm.isNameValid {
                        nameFieldFocused = false
                        onContinue()
                    }
                }
        } primaryAction: {
            nameFieldFocused = false
            onContinue()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                nameFieldFocused = true
            }
        }
    }
}

#Preview {
    OnboardingView { profile in
        print("Onboarding complete: \(profile.name)")
    }
}
