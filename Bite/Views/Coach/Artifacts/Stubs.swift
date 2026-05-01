import SwiftUI

/// TextReport is intentionally light — it just renders the assistant's plain text.
struct TextReportCard: View {
    let artifact: ArtifactMessage
    var body: some View {
        let raw = String(data: artifact.payloadJSON, encoding: .utf8) ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.biteRed)
                Text("Bite report")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
            }
            Text(raw)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.biteInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}
