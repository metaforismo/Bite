import SwiftUI

struct NutritionDetailSheet: View {
    let entry: FoodEntry
    let nutrition: NutritionInfo
    var isSaved: Bool = false
    var onCorrect: ((String) -> Void)?
    var onToggleSaved: (() -> Void)?
    var onRetry: (() -> Void)?
    var onDelete: (() -> Void)?
    var onManualEdit: ((NutritionInfo, String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var correctionText: String = ""
    @State private var showCorrectionField = false
    @State private var showAICorrectionField = false
    @State private var showManualEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text(entry.text)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Photo (if present)
                    photoSection

                    // Nutrition card
                    nutritionCard

                    // Items section
                    itemsSection

                    // AI thought process
                    aiThoughtSection

                    // Sources
                    sourcesSection

                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .safeAreaInset(edge: .bottom) {
                if showAICorrectionField {
                    HStack(spacing: 10) {
                        TextField("Descrivi cosa cambiare...", text: $correctionText)
                            .font(.subheadline)
                            .padding(12)
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))

                        Button {
                            let text = correctionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            onCorrect?(text)
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary.opacity(0.4)
                                    : Color.biteRed
                                )
                        }
                        .disabled(correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.biteBackground)
            .navigationTitle("Dettagli nutrizionali")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            onToggleSaved?()
                        } label: {
                            Label(
                                isSaved ? "Rimuovi dai salvati" : "Salva nei preferiti",
                                systemImage: isSaved ? "bookmark.slash" : "bookmark"
                            )
                        }

                        Menu {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAICorrectionField = true
                                }
                            } label: {
                                Label("Modifica con AI", systemImage: "sparkles")
                            }

                            Button {
                                showManualEditSheet = true
                            } label: {
                                Label("Modifica manualmente", systemImage: "pencil")
                            }
                        } label: {
                            Label("Modifica nutrizione", systemImage: "square.and.pencil")
                        }

                        Button {
                            onRetry?()
                            dismiss()
                        } label: {
                            Label("Ricalcola", systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showManualEditSheet) {
            ManualNutritionEditView(
                currentNutrition: nutrition,
                currentDescription: entry.text
            ) { newNutrition, newText in
                onManualEdit?(newNutrition, newText)
                dismiss()
            }
        }
    }

    // MARK: - Photo Section

    @ViewBuilder
    private var photoSection: some View {
        if let photoFileName = entry.photoFileName,
           let image = PhotoStorageService.shared.loadPhoto(named: photoFileName) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }

    // MARK: - Nutrition Card (Amy style)

    private var nutritionCard: some View {
        VStack(spacing: 16) {
            // Calories header
            HStack(spacing: 6) {
                Text("\u{1F525}")
                    .font(.title2)
                Text("\(nutrition.calories)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("calorie totali")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            }

            // Macros row
            HStack(spacing: 0) {
                macroItem(value: nutrition.protein, emoji: "\u{1F373}", label: "Protein")
                macroItem(value: nutrition.carbs, emoji: "\u{1F34E}", label: "Carbs")
                macroItem(value: nutrition.fat, emoji: "\u{1F347}", label: "Fat")
            }

            // Micros row (if available)
            let hasMicros = nutrition.fiber != nil || nutrition.sugar != nil || nutrition.sodium != nil
            if hasMicros {
                Divider()

                HStack(spacing: 0) {
                    if let sugar = nutrition.sugar {
                        microItem(value: sugar, unit: "g", emoji: "\u{1F48E}", label: "Zuccheri")
                    }
                    if let fiber = nutrition.fiber {
                        microItem(value: fiber, unit: "g", emoji: "\u{1F7E2}", label: "Fibre")
                    }
                    if let sodium = nutrition.sodium {
                        microItem(value: sodium, unit: "mg", emoji: "\u{1F536}", label: "Sodio")
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func macroItem(value: Double, emoji: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(String(format: "%.0fg", value))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                Text(emoji)
                    .font(.caption)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func microItem(value: Double, unit: String, emoji: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(String(format: "%.0f%@", value, unit))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                Text(emoji)
                    .font(.caption2)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alimenti")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack {
                Text(entry.text)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(nutrition.calories) cal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
    }

    // MARK: - AI Thought Process

    @ViewBuilder
    private var aiThoughtSection: some View {
        if let thought = entry.aiThoughtProcess, !thought.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.subheadline)
                        .foregroundStyle(Color.bitePurple)

                    Text("Come ho calcolato")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                if let confidence = nutrition.confidenceLevel {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(confidenceColor(confidence))
                            .frame(width: 8, height: 8)
                        Text("Affidabilità: \(confidence.label)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(confidenceColor(confidence))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(confidenceColor(confidence).opacity(0.15), in: .capsule)
                }

                Text(thought)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bitePurple.opacity(0.06), in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Sources

    @ViewBuilder
    private var sourcesSection: some View {
        if let sources = entry.sources, !sources.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Fonti")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources, id: \.self) { source in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.tertiary)
                                .frame(width: 4, height: 4)

                            Text(source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Confidence Color

    private func confidenceColor(_ level: ConfidenceLevel) -> Color {
        switch level {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NutritionDetailSheet(
                entry: FoodEntry(
                    text: "Pasta al pomodoro con parmigiano",
                    nutrition: NutritionInfo(
                        calories: 420,
                        protein: 14,
                        carbs: 68,
                        fat: 10,
                        fiber: 3.2,
                        sugar: 6.1,
                        sodium: 480,
                        confidenceLevel: .high
                    ),
                    aiThoughtProcess: "Ho stimato una porzione standard di 80g di pasta secca con sugo di pomodoro fresco e una spolverata di parmigiano reggiano (circa 10g).",
                    sources: ["USDA FoodData Central", "Tabelle CREA"]
                ),
                nutrition: NutritionInfo(
                    calories: 420,
                    protein: 14,
                    carbs: 68,
                    fat: 10,
                    fiber: 3.2,
                    sugar: 6.1,
                    sodium: 480,
                    confidenceLevel: .high
                ),
                onCorrect: { _ in }
            )
        }
}
