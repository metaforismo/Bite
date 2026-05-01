import SwiftUI

struct JournalTagsSettingsView: View {
    @State private var disabled: Set<String> = JournalTagCatalog.disabledSet()

    private var grouped: [(category: JournalTagCategory, tags: [JournalTagCatalog.Tag])] {
        let groups = Dictionary(grouping: JournalTagCatalog.all, by: \.category)
        return JournalTagCategory.allCases.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.category) { entry in
                Section(entry.category.displayName) {
                    ForEach(entry.tags) { tag in
                        Toggle(isOn: Binding(
                            get: { !disabled.contains(tag.name) },
                            set: { isOn in
                                if isOn { disabled.remove(tag.name) }
                                else { disabled.insert(tag.name) }
                                JournalTagCatalog.setDisabled(disabled)
                            }
                        )) {
                            Text(tag.name)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .tint(.biteRed)
                    }
                }
            }
        }
        .navigationTitle("Journal tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}
