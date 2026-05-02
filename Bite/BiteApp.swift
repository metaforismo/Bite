import SwiftUI
import SwiftData

@main
struct BiteApp: App {
    @State private var userProfile: UserProfile = .default
    @State private var isLoading = true
    @State private var showV2Welcome = false
    @State private var showV2MiniOnboarding = false
    @State private var pendingDeepLink: BiteDeepLink?

    private let v2OnboardingMarkerKey = "bite_v2_onboarding_seen"

    init() {
        UIWindow.appearance().backgroundColor = UIColor(Color.biteBackground)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    launchScreen
                        .ignoresSafeArea()
                } else if !userProfile.hasCompletedOnboarding {
                    OnboardingView { completedProfile in
                        UserDefaults.standard.set(true, forKey: v2OnboardingMarkerKey)
                        withAnimation(.easeInOut(duration: 0.5)) {
                            userProfile = completedProfile
                        }
                    }
                    .transition(.opacity)
                } else {
                    BiteShell(userProfile: $userProfile, pendingDeepLink: $pendingDeepLink)
                        .transition(.opacity)
                        .sheet(isPresented: $showV2Welcome) {
                            V2WelcomeSheet(
                                onSetupNewFeatures: {
                                    showV2Welcome = false
                                    showV2MiniOnboarding = true
                                },
                                onSkip: {
                                    UserDefaults.standard.set(true, forKey: v2OnboardingMarkerKey)
                                    showV2Welcome = false
                                }
                            )
                            .interactiveDismissDisabled()
                        }
                        .fullScreenCover(isPresented: $showV2MiniOnboarding) {
                            V2MiniOnboardingView(profile: userProfile) { updated in
                                UserDefaults.standard.set(true, forKey: v2OnboardingMarkerKey)
                                userProfile = updated
                                showV2MiniOnboarding = false
                            }
                        }
                }
            }
            .background(Color.biteBackground)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: userProfile.hasCompletedOnboarding)
            .onOpenURL { url in
                if let link = BiteDeepLink(url: url) {
                    pendingDeepLink = link
                }
            }
            .task {
                let loaded = StorageService.shared.loadProfile()
                withAnimation(.easeOut(duration: 0.3)) {
                    userProfile = loaded
                    isLoading = false
                }

                if loaded.hasCompletedOnboarding {
                    NotificationService.shared.scheduleReminderIfNeeded()
                    NotificationService.shared.scheduleDailyReview()

                    // Upgrade-from-V1 path: if the user already completed legacy
                    // onboarding (no V2 marker), show the welcome sheet once.
                    let v2Seen = UserDefaults.standard.bool(forKey: v2OnboardingMarkerKey)
                    if !v2Seen {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showV2Welcome = true
                    }
                }
            }
        }
        .modelContainer(BiteModelContainer.shared)
    }

    private var launchScreen: some View {
        ZStack {
            Color.biteBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("BiteLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 18))

                Text("Bite")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
        }
    }
}
