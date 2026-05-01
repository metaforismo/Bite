import SwiftUI
import SwiftData

struct ActivityStatusSheet: View {
    @Bindable var router: BiteRouter

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\SDActivityStatus.startedAt, order: .reverse)])
    private var statuses: [SDActivityStatus]

    @State private var selected: ActivityStatusKind = .active
    @State private var startedAt: Date = Date()
    @State private var note: String = ""

    private var current: SDActivityStatus? { statuses.first }

    var body: some View {
        ModalSheetContainer(title: "Activity Status", onClose: { router.closeModal() }) {
            VStack(spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        choiceList
                        sinceDatePicker
                        noteField
                    }
                }
                .frame(maxHeight: 380)

                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .onAppear { hydrate() }
        }
    }

    private var choiceList: some View {
        VStack(spacing: 10) {
            ForEach(ActivityStatusKind.allCases, id: \.self) { kind in
                StatusOptionRow(
                    kind: kind,
                    isSelected: selected == kind,
                    select: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selected = kind
                        }
                    }
                )
            }
        }
    }

    private var sinceDatePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Since")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            DatePicker(
                "",
                selection: $startedAt,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.biteRed)
        }
        .padding(.top, 8)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            TextField("Strained right calf, taking a week off running…", text: $note, axis: .vertical)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2...4)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.biteRed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func hydrate() {
        if let current {
            selected = current.kind
            startedAt = current.startedAt
            note = current.note ?? ""
        }
    }

    private func save() {
        let entry = SDActivityStatus(kind: selected, startedAt: startedAt, note: note.isEmpty ? nil : note)
        modelContext.insert(entry)
        try? modelContext.save()
        router.closeModal()
    }
}

private struct StatusOptionRow: View {
    let kind: ActivityStatusKind
    let isSelected: Bool
    let select: () -> Void

    private var tint: Color {
        switch kind {
        case .active: return .biteRingRecovery
        case .sick: return .biteWarning
        case .injured: return .biteOrange
        case .onBreak: return .biteInkMuted
        }
    }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Image(systemName: kind.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : .biteInkMuted)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(isSelected ? tint.opacity(0.18) : Color.black.opacity(0.04))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text(kind.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(tint)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? tint : Color.black.opacity(0.07),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
