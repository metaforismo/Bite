import SwiftUI
import SwiftData

struct FilesScreen: View {
    @Bindable var router: BiteRouter

    private let folders: [Folder] = [
        .init(name: "Memories", systemImage: "folder.fill", destination: .memories),
        .init(name: "Notes", systemImage: "folder.fill", destination: .notes),
        .init(name: "Artifacts", systemImage: "folder.fill", destination: .artifacts),
        .init(name: "Plans", systemImage: "folder.fill", destination: .plans),
        .init(name: "Core", systemImage: "folder.fill", destination: .core),
        .init(name: "Logs", systemImage: "folder.fill", destination: .logs),
        .init(name: "Health Records", systemImage: "folder.fill", destination: .healthRecords),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BiteIntelligenceHeroCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(folders) { folder in
                        NavigationLink(value: folder.destination) {
                            FolderRowContent(name: folder.name, systemImage: folder.systemImage, count: count(for: folder.destination))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Files")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.biteInk)
                        Text("Modified · Most recent")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.biteInkFaint)
                    }
                }
                // Sheet drag-indicator handles dismissal; trailing + opens
                // PlusSheet so the user can attach files via the existing
                // upload flow.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.openPlusSheet() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.biteRed)
                    }
                    .accessibilityLabel("Add")
                }
            }
            .navigationDestination(for: FolderDestination.self) { dest in
                FolderListView(destination: dest)
            }
        }
        .tint(.blue)
    }

    private func count(for destination: FolderDestination) -> Int? {
        // Counts populate via real @Query in FolderListView; on the root we render hyphens.
        nil
    }

    private struct Folder: Identifiable {
        let id = UUID()
        let name: String
        let systemImage: String
        let destination: FolderDestination
    }
}

enum FolderDestination: Hashable {
    case memories, notes, artifacts, plans, core, logs, healthRecords
}

struct FolderRowContent: View {
    let name: String
    let systemImage: String
    let count: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if let count {
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct BiteIntelligenceHeroCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bite Intelligence Files")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.biteInk)
                Text("Files managed by Bite — memories, training plans, and personal preferences.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            redFolderGraphic
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var redFolderGraphic: some View {
        // Stylized red folder evoking the prototype's hero icon.
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFD5D5), Color(hex: 0xFF7A7A)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0xFF7A7A))
                .frame(width: 22, height: 8)
                .offset(x: 8, y: -4)
        }
        .frame(width: 50, height: 42)
    }
}

struct FolderListView: View {
    let destination: FolderDestination

    var body: some View {
        Group {
            switch destination {
            case .memories: MemoriesList()
            case .notes: NotesList()
            case .artifacts: ArtifactsList()
            case .plans: PlansList()
            case .core: CoreList()
            case .logs: LogsList()
            case .healthRecords: HealthRecordsList()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch destination {
        case .memories: return "Memories"
        case .notes: return "Notes"
        case .artifacts: return "Artifacts"
        case .plans: return "Plans"
        case .core: return "Core"
        case .logs: return "Logs"
        case .healthRecords: return "Health Records"
        }
    }
}

struct MemoriesList: View {
    @Query(sort: [SortDescriptor(\CoachMemory.updatedAt, order: .reverse)])
    private var memories: [CoachMemory]
    var body: some View {
        List(memories) { memory in
            NavigationLink(value: memory.id) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(memory.category)
                        .font(.system(size: 15, weight: .semibold))
                    Text(memory.updatedAt, format: .dateTime.month().day().year())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if memories.isEmpty {
                ContentUnavailableView("No memories yet", systemImage: "brain.head.profile", description: Text("Bite extracts memories from your conversations once Coach is connected."))
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let memory = memories.first(where: { $0.id == id }) {
                MemoryDetail(memory: memory)
            }
        }
    }
}

struct NotesList: View {
    @Query(sort: [SortDescriptor(\CoachNote.updatedAt, order: .reverse)])
    private var notes: [CoachNote]
    var body: some View {
        List(notes) { note in
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title).font(.system(size: 15, weight: .semibold))
                Text(note.updatedAt, format: .dateTime.month().day().year())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView("No notes yet", systemImage: "note.text")
            }
        }
    }
}

struct ArtifactsList: View {
    @Query(sort: [SortDescriptor(\CoachMessage.createdAt, order: .reverse)])
    private var messages: [CoachMessage]

    private var artifacts: [ArtifactMessage] {
        messages.compactMap { $0 as? ArtifactMessage }
    }

    var body: some View {
        List(artifacts) { artifact in
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.artifactType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 15, weight: .semibold))
                Text(artifact.createdAt, format: .dateTime.month().day().year())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if artifacts.isEmpty {
                ContentUnavailableView("No artifacts yet", systemImage: "rectangle.stack")
            }
        }
    }
}

struct PlansList: View {
    @Query(sort: [SortDescriptor(\CoachPlan.createdAt, order: .reverse)])
    private var plans: [CoachPlan]
    var body: some View {
        List(plans) { plan in
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title).font(.system(size: 15, weight: .semibold))
                Text("\(plan.weeks)-week plan · \(plan.goal)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if plans.isEmpty {
                ContentUnavailableView("No plans yet", systemImage: "list.bullet.rectangle")
            }
        }
    }
}

struct CoreList: View {
    var body: some View {
        List {
            Text("Onboarding-derived constraints + immutable agent policies live here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
    }
}

struct LogsList: View {
    @Query(sort: [SortDescriptor(\SDFoodEntry.createdAt, order: .reverse)])
    private var entries: [SDFoodEntry]
    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text).font(.system(size: 14, weight: .semibold))
                Text(entry.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }
}

struct HealthRecordsList: View {
    @Query(sort: [SortDescriptor(\SDFile.uploadedAt, order: .reverse)])
    private var files: [SDFile]
    var body: some View {
        List(files) { file in
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName).font(.system(size: 14, weight: .semibold))
                    Text(file.uploadedAt, format: .dateTime.month().day().year())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("No health records yet", systemImage: "doc.text.magnifyingglass", description: Text("Upload labs from the chat composer."))
            }
        }
    }
}

struct MemoryDetail: View {
    @Bindable var memory: CoachMemory
    var body: some View {
        Form {
            Section("Key insight") {
                Text(memory.text)
                    .font(.system(size: 14, weight: .medium))
            }
            Section("Source") {
                Text("Logged from check-ins and HRV data.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(memory.category)
        .navigationBarTitleDisplayMode(.inline)
    }
}
