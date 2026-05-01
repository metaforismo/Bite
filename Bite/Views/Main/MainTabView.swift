import SwiftUI

struct MainTabView: View {
    @Binding var userProfile: UserProfile
    @State private var selectedTab: Tab = .diary
    @State private var diaryViewModel: DiaryViewModel

    init(userProfile: Binding<UserProfile>) {
        self._userProfile = userProfile
        self._diaryViewModel = State(initialValue: DiaryViewModel())
    }

    enum Tab: Hashable {
        case diary
        case analytics
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Diario", systemImage: "note.text", value: Tab.diary) {
                DiaryView(vm: diaryViewModel, userProfile: userProfile)
            }

            SwiftUI.Tab("Analytics", systemImage: "chart.bar.fill", value: Tab.analytics) {
                AnalyticsView(userProfile: userProfile)
            }

            SwiftUI.Tab("Impostazioni", systemImage: "gearshape", value: Tab.settings) {
                SettingsView(userProfile: $userProfile)
            }
        }
        .tint(.biteRed)
    }
}

#Preview {
    @Previewable @State var profile = UserProfile(
        name: "Francesco",
        hasCompletedOnboarding: true
    )
    MainTabView(userProfile: $profile)
}
