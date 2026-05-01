import SwiftUI

struct SavedMealsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        List {
            if vm.savedEntries.isEmpty {
                ContentUnavailableView(
                    "Nessun pasto salvato",
                    systemImage: "bookmark",
                    description: Text("Salva i tuoi pasti preferiti dal diario per accedervi velocemente.")
                )
            } else {
                ForEach(vm.savedEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let cal = entry.nutrition?.calories {
                                Text("\(cal) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .onDelete { indices in
                    let entriesToDelete = indices.map { vm.savedEntries[$0] }
                    for entry in entriesToDelete {
                        vm.removeSavedEntry(entry)
                    }
                }
            }
        }
        .navigationTitle("Pasti salvati")
        .navigationBarTitleDisplayMode(.inline)
    }
}
