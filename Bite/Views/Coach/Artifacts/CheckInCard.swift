import SwiftUI

struct CheckInPayload: Decodable, Sendable {
    let prompt: String
    let cadence: String          // "daily@08:00" | "weekly:monday@09:00"
    let nextFireAt: Date?
    let scheduleId: UUID?
}

struct CheckInCard: View {
    let artifact: ArtifactMessage
    @State private var payload: CheckInPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = payload {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.biteRed)
                    Text("CHECK-IN SCHEDULED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkFaint)
                }
                Text(p.prompt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInk)
                HStack(spacing: 12) {
                    Label(humanCadence(p.cadence), systemImage: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                    if let next = p.nextFireAt {
                        Label {
                            Text(next, format: .dateTime.weekday(.abbreviated).hour().minute())
                        } icon: {
                            Image(systemName: "alarm")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(20)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.biteRedTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { decode() }
    }

    private func humanCadence(_ raw: String) -> String {
        if raw.hasPrefix("daily@") { return "Every day at \(raw.replacingOccurrences(of: "daily@", with: ""))" }
        if raw.hasPrefix("weekly:") { return raw.replacingOccurrences(of: "weekly:", with: "Weekly · ") }
        return raw
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(CheckInPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}
