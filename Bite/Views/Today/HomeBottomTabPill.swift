import SwiftUI

struct HomeBottomTabPill: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(HomeTab.allCases) { tab in
                    Button {
                        guard router.homeTab != tab else { return }
                        BiteHaptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                            router.homeTab = tab
                        }
                    } label: {
                        TabPillItem(tab: tab, isActive: router.homeTab == tab, morphNS: morphNS)
                    }
                    .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.94))
                }
            }
            .padding(6)
            .background(Color.white.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
            .glassEffect(in: .capsule)

            Button {
                BiteHaptics.impact(.medium)
                router.openChat(thenPlus: true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.92))
            .background(Color.white.opacity(0.92), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
            .glassEffect(in: .circle)
        }
    }
}

private struct TabPillItem: View {
    let tab: HomeTab
    let isActive: Bool
    let morphNS: Namespace.ID

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isActive {
                    Capsule()
                        .fill(Color(hex: 0xF2EFEC))
                        .matchedGeometryEffect(id: "activeTabBg", in: morphNS)
                }
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? .biteInk : .biteInkMuted)
            }
            .frame(width: 40, height: 30)
            Text(tab.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? .biteInk : .biteInkMuted)
        }
        .frame(minWidth: 56)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }
}
