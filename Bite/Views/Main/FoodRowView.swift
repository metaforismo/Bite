import SwiftUI

struct FoodRowView: View {
    let entry: FoodEntry
    var onDelete: (() -> Void)?
    var onCorrect: ((String) -> Void)?
    var onToggleSaved: (() -> Void)?
    var onRetry: (() -> Void)?
    var onManualEdit: ((NutritionInfo, String) -> Void)?

    @State private var showDetail = false
    @State private var appeared = false

    var body: some View {
        Button {
            if entry.nutrition != nil {
                showDetail = true
            }
        } label: {
            HStack(spacing: 12) {
                if entry.photoFileName != nil {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if entry.isLoading {
                    loadingShimmer
                } else if let nutrition = entry.nutrition {
                    Text(nutrition.caloriesText)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.biteOrange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onToggleSaved?()
            } label: {
                Label(
                    entry.isSaved ? "Rimuovi dai salvati" : "Salva nei preferiti",
                    systemImage: entry.isSaved ? "bookmark.slash" : "bookmark"
                )
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showDetail) {
            if let nutrition = entry.nutrition {
                NutritionDetailSheet(
                    entry: entry,
                    nutrition: nutrition,
                    isSaved: entry.isSaved,
                    onCorrect: onCorrect,
                    onToggleSaved: onToggleSaved,
                    onRetry: onRetry,
                    onDelete: onDelete,
                    onManualEdit: onManualEdit
                )
            }
        }
    }

    private var loadingShimmer: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(width: 56, height: 16)
            .phaseAnimator([false, true]) { content, phase in
                content.opacity(phase ? 0.4 : 1.0)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
    }
}

#Preview {
    VStack(spacing: 1) {
        FoodRowView(
            entry: FoodEntry(
                text: "Pasta al pomodoro",
                nutrition: NutritionInfo(
                    calories: 420,
                    protein: 12,
                    carbs: 68,
                    fat: 10,
                    fiber: 3,
                    sugar: 6
                )
            )
        )

        FoodRowView(
            entry: FoodEntry(
                text: "Caffe con latte",
                isLoading: true
            )
        )

        FoodRowView(
            entry: FoodEntry(text: "Insalata mista")
        )
    }
    .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    .padding()
}
