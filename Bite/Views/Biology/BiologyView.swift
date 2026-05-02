import SwiftUI
import SwiftData

struct BiologyView: View {
    @Bindable var router: BiteRouter
    @Query(sort: [SortDescriptor(\Biomarker.takenAt, order: .reverse)])
    private var biomarkers: [Biomarker]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BiteTopBar(onBack: nil) { EmptyView() }
                Group {
                    header
                    if !biomarkers.isEmpty {
                        bioAgeOrbit
                    }
                    BiologicalAgeCard(onRefresh: refreshBioAge)
                    BioAgeBreakdownList()
                    BioAgeChart3D()
                    Text("BIOMARKERS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.biteInkMuted)
                        .padding(.leading, 4)
                        .padding(.top, 6)
                    if biomarkers.isEmpty {
                        emptyState
                    } else {
                        biomarkerGroups
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Marquee biomarker orbit. Each marker becomes a tiny indicator at
    /// its evenly-spaced angle, color-coded by status (in-range green,
    /// out-of-range red). Center shows the count of markers tracked.
    /// Uses the biology palette (purple/cosmic) so it stands apart from
    /// nutrition/sleep dials elsewhere.
    private var bioAgeOrbit: some View {
        let unique = Array(biomarkers.prefix(24))
        let indicators: [DialIndicator] = unique.enumerated().map { idx, marker in
            DialIndicator(
                angle: Double(idx) / Double(max(1, unique.count)) * 360.0,
                color: statusColor(marker.status),
                size: 12,
                inset: 12,
                systemImage: nil,
                glow: marker.status != .inRange
            )
        }
        let inRangeCount = biomarkers.filter { $0.status == .inRange }.count

        return OrbitDial(
            theme: .biology,
            arcs: [],
            indicators: indicators
        ) {
            VStack(spacing: 2) {
                Text("\(biomarkers.count)")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("biomarkers")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(inRangeCount) in range")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color(hex: 0x9C7BFF))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 280, maxHeight: 280)
        .padding(.vertical, 8)
        .askCoachContext("Walk me through my biomarker panel — anything I should look at?")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Biology")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(.biteInk)
            Text("Biomarkers extracted from your labs")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
    }

    private func refreshBioAge() {
        router.openChat(prefill: "Compute my biological age from my latest labs, sleep, activity, and nutrition data.")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "testtube.2")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.biteRedSoft)
                .padding(20)
                .background(.biteRedTint, in: Circle())
            Text("Upload a lab report")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.biteInk)
            Text("Share a PDF of your bloodwork. Bite extracts every biomarker, flags out-of-range values, and builds a clinician-friendly summary.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.biteInkMuted)
                .multilineTextAlignment(.center)
            Button {
                router.openChat(thenPlus: true)
            } label: {
                Text("Upload labs")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(.biteRed, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var biomarkerGroups: some View {
        let grouped: [String: [Biomarker]] = Dictionary(grouping: biomarkers, by: { $0.category })
        let categories = grouped.keys.sorted()
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(categories, id: \.self) { category in
                BiomarkerCategorySection(
                    title: category,
                    markers: grouped[category] ?? []
                )
            }
        }
    }

    private func statusColor(_ status: BiomarkerStatus) -> Color {
        switch status {
        case .inRange: return .biteRingRecovery
        case .high, .low: return .biteRed
        case .unknown: return .biteInk
        }
    }
}

private struct BiomarkerCategorySection: View {
    let title: String
    let markers: [Biomarker]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(markers) { BiomarkerRow(marker: $0) }
            }
        }
    }
}

private struct BiomarkerRow: View {
    let marker: Biomarker

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(marker.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInk)
                if let lo = marker.refLow, let hi = marker.refHigh {
                    Text("Reference: \(Int(lo))–\(Int(hi)) \(marker.unit)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Text(String(format: "%.1f", marker.value))
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(statusColor)
                Text(marker.unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch marker.status {
        case .inRange: return .biteRingRecovery
        case .high, .low: return .biteRed
        case .unknown: return .biteInk
        }
    }

    private func statusColor(_ status: BiomarkerStatus) -> Color {
        switch status {
        case .inRange: return .biteRingRecovery
        case .high, .low: return .biteRed
        case .unknown: return .biteInk
        }
    }
}
