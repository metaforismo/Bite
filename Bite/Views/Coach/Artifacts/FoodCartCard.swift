import SwiftUI
import SwiftData

struct FoodCartPayload: Decodable, Sendable {
    let dishName: String
    let kcal: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let mealLabel: String?     // "Lunch", "Snack", ...
    let mealAt: Date?
    let badge: String?
    let whyItsGood: String?
    let portionLabel: String?
}

struct FoodCartCard: View {
    let artifact: ArtifactMessage
    @Environment(\.modelContext) private var modelContext

    @State private var payload: FoodCartPayload?
    @State private var lastVersion: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let p = payload {
                content(for: p)
            } else {
                ProgressView()
                    .padding(40)
                    .frame(maxWidth: .infinity)
            }
        }
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
    private func content(for p: FoodCartPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xFFD5C2), Color(hex: 0xF4A532)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("🥗").font(.system(size: 22))
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        Text(p.dishName)
                            .font(.system(size: 15, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(.biteInk)
                        Spacer()
                        if let badge = p.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.3)
                                .foregroundStyle(.biteRingRecovery)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.biteRingRecovery.opacity(0.13), in: Capsule())
                        }
                    }
                    if let label = p.mealLabel {
                        Text("\(p.mealAt.map { dateString($0) } ?? "") · \(label)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.biteInkFaint)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(p.kcal)")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(.biteInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkFaint)
                }
                Spacer()
                HStack(spacing: 14) {
                    MacroPill(label: "Protein", value: Int(p.protein), color: .biteRed)
                    MacroPill(label: "Carbs",   value: Int(p.carbs),   color: .biteCarbs)
                    MacroPill(label: "Fat",     value: Int(p.fat),     color: .biteFat)
                    MacroPill(label: "Fiber",   value: Int(p.fiber ?? 0), color: .biteFiber)
                }
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Divider().overlay(Color(hex: 0xF0EFEE)) }
            .overlay(alignment: .bottom) { Divider().overlay(Color(hex: 0xF0EFEE)) }

            if let why = p.whyItsGood {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why it's good")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.biteInk)
                    Text(why)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }
            }
        }
        .padding(16)
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(FoodCartPayload.self, from: artifact.payloadJSON) else { return }
        if artifact.version > lastVersion {
            withAnimation(BiteMotion.countPop) {
                payload = decoded
            }
            lastVersion = artifact.version
        } else {
            payload = decoded
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

private struct MacroPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.2)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text("g")
                    .font(.system(size: 10))
                    .foregroundStyle(.biteInkFaint)
            }
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.biteInkFaint)
        }
    }
}

extension JSONDecoder {
    static let bite: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
