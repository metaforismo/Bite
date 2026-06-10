import SwiftUI
import SwiftData

/// Lists every `LabReport` the user has uploaded. Reachable from the Coach
/// drawer ("Health Records" row) and from the unified `LogSheet` →
/// "Files & lab reports" path.
struct HealthRecordsScreen: View {
    @Bindable var router: BiteRouter

    @Query(sort: [SortDescriptor(\LabReport.takenAt, order: .reverse)])
    private var reports: [LabReport]

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            content
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
            VStack(spacing: 2) {
                Text("Health Records")
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(.biteInk)
                Text("\(reports.count) report\(reports.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button(action: { router.closeHealthRecords() }) {
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

    @ViewBuilder
    private var content: some View {
        if reports.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(reports) { report in
                        ReportRow(report: report)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.biteInkFaint)
            Text("No lab reports yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.biteInk)
            Text("Upload a PDF or image of your bloodwork via the Coach Files panel to see results here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button(action: {
                router.closeHealthRecords()
                router.openFiles()
            }) {
                Text("Open Files")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
            .background(.biteInk, in: Capsule())
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

private struct ReportRow: View {
    let report: LabReport

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.biteRedTint)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.biteRed)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(report.title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(.biteInk)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: report.takenAt))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                    if report.confidence > 0 {
                        Text("·")
                            .foregroundStyle(.biteInkFaint.opacity(0.5))
                        Text("\(Int(report.confidence * 100))% confidence")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(0.3)
                            .foregroundStyle(.biteRingRecovery)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.biteInkFaint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0xFAF7F2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
