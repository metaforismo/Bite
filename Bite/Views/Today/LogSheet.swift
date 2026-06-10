import SwiftUI

/// Unified "log something" entry point — replaces the awkward
/// `openChat(thenPlus: true)` workaround. Each row routes to an existing
/// modal sheet or to the Coach with the right prefill, so logging any kind
/// of state lives in one menu instead of being spread across tabs.
struct LogSheet: View {
    @Bindable var router: BiteRouter

    private struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let tint: Color
        let action: () -> Void
    }

    private var rows: [Row] {
        [
            Row(
                icon: "fork.knife",
                title: "Food",
                subtitle: "Log a meal with photo, voice, or text",
                tint: .biteRed,
                action: {
                    router.closeLogSheet()
                    router.openChat(prefill: "Log my last meal — what should I tell you?")
                }
            ),
            Row(
                icon: "drop.fill",
                title: "Water",
                subtitle: "Track a glass, bottle, or cup",
                tint: .biteHydration,
                action: { router.closeLogSheet(); router.openModal(.hydration) }
            ),
            Row(
                icon: "cup.and.saucer.fill",
                title: "Caffeine",
                subtitle: "Coffee, tea, or energy drinks",
                tint: .biteCarbs,
                action: { router.closeLogSheet(); router.openModal(.caffeine) }
            ),
            Row(
                icon: "moon.stars.fill",
                title: "Sleep",
                subtitle: "Bedtime, wake, smart alarm",
                tint: .biteFat,
                action: { router.closeLogSheet(); router.openModal(.smartAlarm) }
            ),
            Row(
                icon: "figure.run",
                title: "Activity status",
                subtitle: "Active, recovering, paused",
                tint: .biteRingRecovery,
                action: { router.closeLogSheet(); router.openModal(.activityStatus) }
            ),
            Row(
                icon: "calendar.badge.clock",
                title: "Cycle",
                subtitle: "Period, ovulation, symptoms",
                tint: .biteRedSoft,
                action: { router.closeLogSheet(); router.openModal(.menstrualLog) }
            ),
            Row(
                icon: "scalemass.fill",
                title: "Weight",
                subtitle: "Update your current weight",
                tint: .biteFiber,
                action: {
                    router.closeLogSheet()
                    router.openChat(prefill: "Log my weight: ")
                }
            ),
            Row(
                icon: "folder.fill",
                title: "Files & lab reports",
                subtitle: "Attach docs, photos, or labs",
                tint: .biteInkMuted,
                action: { router.closeLogSheet(); router.openFiles() }
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(rows) { row in
                        Button(action: {
                            BiteHaptics.selection()
                            row.action()
                        }) {
                            rowView(for: row)
                        }
                        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.97))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
    }

    private var handle: some View {
        Capsule()
            .fill(Color(hex: 0xE5E5EA))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("Log something")
                .font(.system(size: 16, weight: .heavy))
                .tracking(-0.2)
                .foregroundStyle(.biteInk)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button(action: { router.closeLogSheet() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0xF0EFEE), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func rowView(for row: Row) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(row.tint.opacity(0.14))
                Image(systemName: row.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(row.tint)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.biteInk)
                Text(row.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.biteInkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
