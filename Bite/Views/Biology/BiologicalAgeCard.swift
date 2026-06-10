import SwiftUI
import SwiftData

/// Top-of-Biology card showing biological age + delta to chronological age + a
/// 0–100% confidence dial. Reads the most recent `BiologicalAgeSnapshot`
/// (worker-generated, cached locally). Empty state nudges the user to upload
/// labs since lab biomarkers materially improve confidence.
struct BiologicalAgeCard: View {
    @Query(sort: [SortDescriptor(\BiologicalAgeSnapshot.computedAt, order: .reverse)])
    private var snapshots: [BiologicalAgeSnapshot]

    let onRefresh: () -> Void

    private var latest: BiologicalAgeSnapshot? { snapshots.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let latest {
                HStack(alignment: .center, spacing: 18) {
                    bigNumeral(latest)
                    Spacer()
                    ConfidenceRing(confidence: latest.confidence)
                        .frame(width: 82, height: 82)
                }
                deltaLine(latest)
            } else {
                emptyState
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var header: some View {
        HStack {
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.biteRedSoft)
            Text("BIOLOGICAL AGE")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.biteInkMuted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
    }

    private func bigNumeral(_ s: BiologicalAgeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Biological age")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.biteInkFaint)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(String(format: "%.1f", s.biologicalAge))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.biteInk)
            Text("years")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.biteInkMuted)
            }
        }
    }

    private func deltaLine(_ s: BiologicalAgeSnapshot) -> some View {
        let delta = s.deltaYears
        let isYounger = delta > 0
        let color: Color = isYounger ? .biteRingRecovery : .biteRed
        let label = isYounger
            ? String(format: "%.1f years younger", abs(delta))
            : String(format: "%.1f years older", abs(delta))
        return HStack(spacing: 6) {
            Image(systemName: isYounger ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 11, weight: .heavy))
            Text(label)
                .font(.system(size: 13, weight: .heavy))
            Text("vs. chronological")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
        .foregroundStyle(color)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimate not ready")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.biteInk)
            Text("Bite needs at least a week of sleep + activity data and one lab report to give you a confident biological-age estimate.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
    }

    private func confidenceLabel(_ c: Double) -> String {
        if c >= 0.8 { return "High-quality estimate with minor gaps" }
        if c >= 0.5 { return "Good estimate, more lab data improves accuracy" }
        return "Low-confidence estimate"
    }
}

private struct ConfidenceRing: View {
    let confidence: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, max(0, confidence)))
                .stroke(Color.biteRingRecovery, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(confidence * 100))%")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                Text("conf.")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(.biteInkFaint)
            }
        }
    }
}
