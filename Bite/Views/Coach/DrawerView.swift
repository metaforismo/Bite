import SwiftUI
import SwiftData

struct DrawerView: View {
    @Bindable var router: BiteRouter
    @Query(sort: [SortDescriptor(\CoachThread.lastMessageAt, order: .reverse)])
    private var threads: [CoachThread]

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = geometry.size.width * 0.82
            ZStack(alignment: .leading) {
                Color.black.opacity(router.drawerOpen ? 0.4 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { router.toggleDrawer() }
                    .animation(BiteMotion.scrimFade, value: router.drawerOpen)

                drawerSurface
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: router.drawerOpen ? 0 : -drawerWidth)
                    .animation(BiteMotion.drawerSlide, value: router.drawerOpen)
            }
        }
        .allowsHitTesting(router.drawerOpen)
    }

    private var drawerSurface: some View {
        VStack(spacing: 0) {
            search
            topLinks
            history
            settingsFooter
        }
        .padding(.top, BiteTheme.deviceSafeAreaTop + BiteTheme.topBarTopOffset)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 1)
        }
        .ignoresSafeArea()
    }

    private var search: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: 0x8E8E93))
                Text("Search")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x8E8E93))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(white: 0, opacity: 0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {} label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0, opacity: 0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var topLinks: some View {
        VStack(spacing: 0) {
            DrawerRow(systemImage: "doc.text.fill", title: "Health Records", iconColor: .biteRed) {}
            DrawerRow(systemImage: "folder.fill", title: "Files", iconColor: .biteRedSoft) {
                router.openFiles()
            }
        }
        .padding(.horizontal, 8)
    }

    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let pinned = threads.filter(\.pinned)
                let calendar = Calendar.current
                let today = threads.filter { !$0.pinned && calendar.isDateInToday($0.lastMessageAt) }
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let prev7 = threads.filter { !$0.pinned && !calendar.isDateInToday($0.lastMessageAt) && $0.lastMessageAt >= weekAgo }

                if !pinned.isEmpty {
                    DrawerHeader("Pinned")
                    ForEach(pinned) { ChatHistoryRow(thread: $0) }
                }
                if !today.isEmpty {
                    DrawerHeader("Today")
                    ForEach(today) { ChatHistoryRow(thread: $0) }
                }
                if !prev7.isEmpty {
                    DrawerHeader("Previous 7 days")
                    ForEach(prev7) { ChatHistoryRow(thread: $0) }
                }
                if threads.isEmpty {
                    Text("No conversations yet.\nAsk Bite anything to get started.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                        .multilineTextAlignment(.leading)
                        .padding(20)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var settingsFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.biteInkMuted)
            Text("Settings")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.biteInk)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: 0xF8F6F4).opacity(0.7))
        .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.05)).frame(height: 1) }
    }
}

private struct DrawerHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(.biteInkFaint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.top, 6)
    }
}

private struct DrawerRow: View {
    let systemImage: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.biteInk)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ChatHistoryRow: View {
    let thread: CoachThread
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.biteInk)
                    .lineLimit(1)
                Text(thread.lastMessageAt, style: .relative)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
            }
            Spacer()
            if thread.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.biteInkFaint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
