import SwiftUI

struct TrainingPlanPayload: Decodable, Sendable {
    let title: String
    let goal: String
    let targetPace: String?
    let startDate: Date?
    let weeks: [Week]

    struct Week: Decodable, Identifiable, Sendable {
        let id: UUID
        let number: Int
        let summary: String?
        let days: [Day]
    }

    struct Day: Decodable, Identifiable, Sendable {
        let id: UUID
        let label: String        // "Mon", "Tue", ...
        let workout: String
        let status: String       // "done" | "partial" | "skipped" | "missing" | "upcoming"
    }
}

struct TrainingPlanCard: View {
    let artifact: ArtifactMessage
    @State private var payload: TrainingPlanPayload?
    @State private var expandedWeek: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let p = payload {
                header(p)
                metadata(p)
                weeks(p)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 2)
        .onAppear { decode() }
    }

    private func header(_ p: TrainingPlanPayload) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteRed)
                Text("TRAINING PLAN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.biteInkFaint)
            }
            Text(p.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.biteInk)
        }
    }

    @ViewBuilder
    private func metadata(_ p: TrainingPlanPayload) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataRow(label: "Goal", value: p.goal)
            if let pace = p.targetPace {
                metadataRow(label: "Target pace", value: pace)
            }
            if let start = p.startDate {
                metadataRow(label: "Start date", value: dateString(start))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.biteInkFaint)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.biteInk)
        }
    }

    private func weeks(_ p: TrainingPlanPayload) -> some View {
        VStack(spacing: 8) {
            ForEach(p.weeks) { week in
                WeekDisclosure(
                    week: week,
                    isExpanded: expandedWeek == week.number,
                    onToggle: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            expandedWeek = expandedWeek == week.number ? nil : week.number
                        }
                    }
                )
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(TrainingPlanPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}

private struct WeekDisclosure: View {
    let week: TrainingPlanPayload.Week
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text("WEEK \(week.number)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInk)
                    if let summary = week.summary {
                        Text("·")
                            .foregroundStyle(.biteInkFaint)
                        Text(summary)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.biteInkMuted)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
                .padding(10)
            }
            .buttonStyle(.plain)
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(week.days) { day in
                        HStack {
                            Text(day.label)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 36, alignment: .leading)
                                .foregroundStyle(.biteInk)
                            Text(day.workout)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.biteInkMuted)
                            Spacer()
                            StatusTag(status: day.status)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusTag: View {
    let status: String
    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.13), in: Capsule())
    }
    private var color: Color {
        switch status.lowercased() {
        case "done":     return .biteRingRecovery
        case "partial":  return .biteWarning
        case "skipped":  return .biteInkFaint
        case "missing":  return .biteRed
        default:         return .biteInkMuted
        }
    }
}
