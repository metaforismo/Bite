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
            agentHeader
            search
            topLinks
            agentWorkspace
            history
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

    private var agentHeader: some View {
        HStack(spacing: 10) {
            BiteOrbImage(size: 38, mood: .neutral, state: .idle, showHalo: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bite Agent")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text("Research, files, memory, health data")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
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

            Button {
                BiteHaptics.impact(.light)
                router.startNewChat()
            } label: {
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
            DrawerRow(systemImage: "doc.text.fill", title: "Health Records", iconColor: .biteRed) {
                router.openHealthRecords()
            }
            DrawerRow(systemImage: "folder.fill", title: "Files", iconColor: .biteRedSoft) {
                router.openFiles()
            }
        }
        .padding(.horizontal, 8)
    }

    private var agentWorkspace: some View {
        VStack(alignment: .leading, spacing: 8) {
            DrawerHeader("Agent workspace")
            VStack(spacing: 8) {
                DrawerCapabilityRow(systemImage: "book.closed.fill", title: "Science research", value: "PubMed + web", tint: .biteRingSleep)
                DrawerCapabilityRow(systemImage: "waveform.path.ecg", title: "Health context", value: "Apple Health", tint: .biteRingRecovery)
                DrawerCapabilityRow(systemImage: "brain.head.profile", title: "Memory", value: "Local facts", tint: .biteCarbs)
            }
            .padding(12)
            .background(Color.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.62), lineWidth: 1))
            .padding(.horizontal, 8)
        }
    }

    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let pinned = threads.filter(\.pinned)
                let calendar = Calendar.current
                let today = threads.filter { !$0.pinned && calendar.isDateInToday($0.lastMessageAt) }
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let prev7 = threads.filter { !$0.pinned && !calendar.isDateInToday($0.lastMessageAt) && $0.lastMessageAt >= weekAgo }
                let earlier = threads.filter { !$0.pinned && $0.lastMessageAt < weekAgo }

                DrawerHeader("Agent History")
                DrawerRow(systemImage: "plus.bubble.fill", title: "New chat", iconColor: .biteInk) {
                    router.startNewChat()
                }

                if !pinned.isEmpty {
                    DrawerHeader("Pinned")
                    ForEach(pinned) { thread in
                        ChatHistoryRow(thread: thread) { router.openChatThread(thread) }
                    }
                }
                if !today.isEmpty {
                    DrawerHeader("Today")
                    ForEach(today) { thread in
                        ChatHistoryRow(thread: thread) { router.openChatThread(thread) }
                    }
                }
                if !prev7.isEmpty {
                    DrawerHeader("Previous 7 days")
                    ForEach(prev7) { thread in
                        ChatHistoryRow(thread: thread) { router.openChatThread(thread) }
                    }
                }
                if !earlier.isEmpty {
                    DrawerHeader("Earlier")
                    ForEach(earlier) { thread in
                        ChatHistoryRow(thread: thread) { router.openChatThread(thread) }
                    }
                }
                if threads.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No conversations yet")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.biteInk)
                        Text("Ask Bite about nutrition, training, labs, papers, or your uploaded files. Threads will live here.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 8)
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

private struct DrawerCapabilityRow: View {
    let systemImage: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
            Text(title)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(.biteInk)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ChatHistoryRow: View {
    let thread: CoachThread
    let action: () -> Void

    private var lastSnippet: String {
        thread.messages.sorted { $0.createdAt > $1.createdAt }.first?.text ?? "No messages yet"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.62), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.biteInk)
                        .lineLimit(1)
                    Text(lastSnippet)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                        .lineLimit(1)
                    Text(thread.lastMessageAt, style: .relative)
                        .font(.system(size: 10.5, weight: .medium))
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
            .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
    }
}
