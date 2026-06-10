import SwiftUI

struct ArtifactRouterView: View {
    let artifact: ArtifactMessage

    var body: some View {
        switch artifact.artifactType {
        case "food_cart":
            ProposedActionCard(artifact: artifact)
        case "lab_report":
            LabReportCard(artifact: artifact)
        case "chart":
            ChartArtifactCard(artifact: artifact)
        case "box_plot":
            BoxPlotCard(artifact: artifact)
        case "confidence_dial":
            ConfidenceDialCard(artifact: artifact)
        case "training_plan":
            TrainingPlanCard(artifact: artifact)
        case "workout":
            WorkoutCard(artifact: artifact)
        case "check_in":
            CheckInCard(artifact: artifact)
        case "text_report":
            TextReportCard(artifact: artifact)
        default:
            UnknownArtifactCard(artifact: artifact)
        }
    }
}

struct UnknownArtifactCard: View {
    let artifact: ArtifactMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Artifact: \(artifact.artifactType)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.biteInkMuted)
            Text("(unsupported in this build)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.biteInkFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
