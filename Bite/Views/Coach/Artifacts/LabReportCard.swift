import SwiftUI
import SwiftData

struct LabReportPayload: Decodable, Sendable {
    let title: String
    let takenAt: Date?
    let confidence: Double
    let sourceFileName: String?
    let biomarkers: [Item]
    let summary: String?

    struct Item: Decodable, Identifiable, Sendable {
        let id: UUID
        let name: String
        let category: String
        let value: Double
        let unit: String
        let refLow: Double?
        let refHigh: Double?
        let status: String        // "in_range" | "high" | "low" | "unknown"
    }
}

struct LabReportCard: View {
    let artifact: ArtifactMessage

    @Environment(BiteRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var payload: LabReportPayload?
    @State private var saved: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let p = payload {
                content(for: p)
            } else {
                ProgressView().padding(40).frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.smallCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.smallCardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 2)
        .onAppear { decode() }
        .onChange(of: artifact.version) { _, _ in decode() }
    }

    @ViewBuilder
    private func content(for p: LabReportPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.biteRed)
                        Text("LAB REPORT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.biteInkFaint)
                    }
                    Text(p.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.biteInk)
                    if let date = p.takenAt {
                        Text(date, format: .dateTime.month().day().year())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.biteInkFaint)
                    }
                }
                Spacer()
                ConfidenceBadge(value: p.confidence)
            }

            // Quick at-a-glance count of in-range / out-of-range markers.
            statusSummary(for: p.biomarkers)

            if let summary = p.summary {
                Text(summary)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.biteInk.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            biomarkerGroups(p.biomarkers)

            if let source = p.sourceFileName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                    Text("Source: \(source)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.biteInkFaint)
            }

            // Mandatory clinical safety strings.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteWarning)
                    Text("Not a diagnosis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.biteInk)
                }
                Text("Discuss any out-of-range values with a clinician before changing medication, supplements, or routines.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFF7E8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            actionFooter(for: p)
        }
    }

    private func statusSummary(for items: [LabReportPayload.Item]) -> some View {
        let inRange = items.filter { $0.status == "in_range" }.count
        let outOfRange = items.filter { $0.status == "high" || $0.status == "low" }.count
        return HStack(spacing: 10) {
            statusPill(count: inRange, label: "in range", color: .biteRingRecovery)
            if outOfRange > 0 {
                statusPill(count: outOfRange, label: "out of range", color: .biteRed)
            }
            Spacer()
        }
    }

    private func statusPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.biteInk)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10), in: Capsule())
    }

    private func actionFooter(for p: LabReportPayload) -> some View {
        HStack(spacing: 8) {
            Button(action: { askFollowUp(p) }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Ask follow-up")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .foregroundStyle(.biteInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
            .buttonStyle(.plain)

            Button(action: { saveToHealthRecords(p) }) {
                HStack(spacing: 5) {
                    Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 11, weight: .heavy))
                    Text(saved ? "Saved" : "Save report")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .background(.biteInk, in: Capsule())
            .buttonStyle(.plain)
            .disabled(saved)
        }
    }

    private func askFollowUp(_ p: LabReportPayload) {
        BiteHaptics.impact(.light)
        let prefill = "Tell me more about this lab report — what should I focus on, and what habits would help?"
        router.prefilledChatPrompt = prefill
    }

    private func saveToHealthRecords(_ p: LabReportPayload) {
        BiteHaptics.impact(.light)
        let report = LabReport(
            title: p.title,
            takenAt: p.takenAt ?? Date(),
            confidence: p.confidence
        )
        modelContext.insert(report)
        try? modelContext.save()
        saved = true
    }

    private func biomarkerGroups(_ items: [LabReportPayload.Item]) -> some View {
        let grouped: [String: [LabReportPayload.Item]] = Dictionary(grouping: items, by: { $0.category })
        let categories = grouped.keys.sorted()
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(categories, id: \.self) { category in
                Text(category.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.biteInkFaint)
                VStack(spacing: 6) {
                    ForEach(grouped[category] ?? []) { item in
                        BiomarkerRowSmall(item: item)
                    }
                }
            }
        }
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(LabReportPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}

private struct BiomarkerRowSmall: View {
    let item: LabReportPayload.Item

    private var statusColor: Color {
        switch item.status {
        case "in_range": return .biteRingRecovery
        case "high", "low": return .biteRed
        default: return .biteInk
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                if let lo = item.refLow, let hi = item.refHigh {
                    Text("Ref \(Int(lo))–\(Int(hi)) \(item.unit)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Text(String(format: "%.1f", item.value))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(statusColor)
                Text(item.unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ConfidenceBadge: View {
    let value: Double      // 0...1
    var body: some View {
        VStack(spacing: 1) {
            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.biteRed)
            Text("CONF")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.biteInkFaint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.biteRedTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
