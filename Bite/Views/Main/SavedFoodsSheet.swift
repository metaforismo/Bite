import SwiftUI

struct SavedFoodsSheet: View {
    @Bindable var vm: DiaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredEntries: [FoodEntry] {
        if searchText.isEmpty {
            return vm.savedEntries
        }
        return vm.savedEntries.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.savedEntries.isEmpty {
                    ContentUnavailableView(
                        "Nessun cibo salvato",
                        systemImage: "bookmark",
                        description: Text("Salva i cibi dal diario per aggiungerli velocemente.")
                    )
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            Button {
                                vm.addSavedEntry(entry)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.text)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        if let nutrition = entry.nutrition {
                                            Text(nutrition.caloriesText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.biteRed)
                                        .font(.title3)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    vm.removeSavedEntry(entry)
                                } label: {
                                    Label("Rimuovi", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Cerca nei salvati...")
                }
            }
            .navigationTitle("Cibi salvati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
    }
}
