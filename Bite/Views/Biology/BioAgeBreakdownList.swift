import SwiftUI
import SwiftData

/// 5 disclosure rows (Sleep / Activity / Fitness / Lifestyle / Blood). Each
/// expands to show the underlying drivers with their year-deltas (negative =
/// taking years off → green; positive = adding years → red).
struct BioAgeBreakdownList: View {
    @Query(sort: [SortDescriptor(\BiologicalAgeSnapshot.computedAt, order: .reverse)])
    private var snapshots: [BiologicalAgeSnapshot]

    private var breakdown: BioAgeBreakdown { snapshots.first?.breakdown ?? .empty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREAKDOWN")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
                .padding(.leading, 4)

            CategoryDisclosure(title: "Sleep",     icon: "moon.zzz.fill",         tint: .biteRingSleep,    drivers: breakdown.sleep)
            CategoryDisclosure(title: "Activity",  icon: "figure.run",            tint: .biteRingRecovery, drivers: breakdown.activity)
            CategoryDisclosure(title: "Fitness",   icon: "heart.fill",            tint: .biteRed,          drivers: breakdown.fitness)
            CategoryDisclosure(title: "Lifestyle", icon: "leaf.fill",             tint: .biteFiber,        drivers: breakdown.lifestyle)
            CategoryDisclosure(title: "Blood",     icon: "testtube.2",            tint: .biteOrange,       drivers: breakdown.blood)
        }
    }
}

private struct CategoryDisclosure: View {
    let title: String
    let icon: String
    let tint: Color
    let drivers: [BioAgeBreakdown.Driver]

    @State private var expanded: Bool = false

    private var summaryDelta: Double {
        drivers.map(\.deltaYears).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(tint.opacity(0.14)))

                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.biteInk)

                    Spacer()

                    if !drivers.isEmpty {
                        Text(String(format: "%+.1f y", summaryDelta))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(summaryDelta < 0 ? .biteRingRecovery : .biteRed)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.biteInkFaint)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded && !drivers.isEmpty {
                VStack(spacing: 6) {
                    ForEach(drivers) { driver in
                        DriverRow(driver: driver)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct DriverRow: View {
    let driver: BioAgeBreakdown.Driver

    var body: some View {
        HStack {
            Text(driver.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.biteInk)
            Spacer()
            Text(String(format: "%+.1f y", driver.deltaYears))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(driver.deltaYears < 0 ? .biteRingRecovery : .biteRed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.03))
        }
    }
}
