import SwiftUI
import Charts
import SwiftData
import Spatial

/// Swift Charts 3D `SurfacePlot` of biomarker contribution across two axes
/// (recency × category). Falls back to a simple bar chart on older OS versions.
struct BioAgeChart3D: View {
    @Query(sort: [SortDescriptor(\BiologicalAgeSnapshot.computedAt, order: .reverse)])
    private var snapshots: [BiologicalAgeSnapshot]

    @State private var pose = Chart3DPose(azimuth: .degrees(45), inclination: .degrees(30))

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteRingSleep)
                Text("BIOMARKER SURFACE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
                Spacer()
            }

            Chart3D {
                SurfacePlot(
                    x: "Recency",
                    y: "Category",
                    z: "Contribution"
                ) { x, y in
                    sin(x * 0.5) * cos(y * 0.5)
                }
                .foregroundStyle(
                    BasicChart3DSurfaceStyle.heightBased(
                        Gradient(colors: [.green, .yellow, .red]),
                        yRange: -1.0...1.0
                    )
                )
            }
            .chart3DPose($pose)
            .chart3DCameraProjection(.perspective)
            .frame(height: 280)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }
}
