import SwiftUI

/// Re-skinned legacy diary surfaced under the Journal tab.
struct JournalView: View {
    @State private var vm: DiaryViewModel = DiaryViewModel()
    @State private var profile = StorageService.shared.loadProfile()
    @State private var tab: Tab = .diary

    enum Tab: Hashable, CaseIterable { case diary, insights }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BiteTopBar(onBack: nil) { EmptyView() }

                Text("Journal")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(.biteInk)
                    .padding(.horizontal, 20)

                Picker("", selection: $tab) {
                    Text("Diary").tag(Tab.diary)
                    Text("Insights").tag(Tab.insights)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                switch tab {
                case .diary:
                    DiaryView(vm: vm, userProfile: profile)
                case .insights:
                    JournalInsightsView()
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .task { await vm.loadDay() }
    }
}
