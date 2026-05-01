import SwiftUI
import SwiftData

struct MenstrualLogSheet: View {
    @Bindable var router: BiteRouter

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\SDCycleEntry.date, order: .reverse)])
    private var allEntries: [SDCycleEntry]

    @State private var date: Date = Calendar.current.startOfDay(for: Date())
    @State private var flowLevel: Int = 0
    @State private var symptomsSet: Set<String> = []

    private static let symptoms = [
        "Cramps", "Headache", "Bloating", "Mood swings",
        "Fatigue", "Acne", "Tender breasts", "Lower back pain",
    ]

    var body: some View {
        ModalSheetContainer(title: "Log cycle entry", onClose: { router.closeModal() }) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    dateField
                    flowField
                    symptomsField
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: 520)
            .onAppear { hydrateForToday() }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Date")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.biteRedSoft)
                .onChange(of: date) { _, _ in hydrateForSelectedDate() }
        }
    }

    private var flowField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flow")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            HStack(spacing: 8) {
                ForEach(Array([(0, "None"), (1, "Light"), (2, "Medium"), (3, "Heavy")].enumerated()), id: \.offset) { _, pair in
                    let level = pair.0
                    let label = pair.1
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            flowLevel = level
                        }
                    } label: {
                        Text(label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(flowLevel == level ? .white : .biteInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(flowLevel == level ? Color.biteRedSoft : Color.white)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        flowLevel == level ? Color.biteRedSoft : Color.black.opacity(0.07),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var symptomsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symptoms")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.symptoms, id: \.self) { symptom in
                    let on = symptomsSet.contains(symptom)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            if on {
                                symptomsSet.remove(symptom)
                            } else {
                                symptomsSet.insert(symptom)
                            }
                        }
                    } label: {
                        Text(symptom)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? .white : .biteInk)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(on ? Color.biteRedSoft : Color.white)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        on ? Color.biteRedSoft : Color.black.opacity(0.07),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save entry")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.biteRedSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func hydrateForToday() { hydrateForSelectedDate() }

    private func hydrateForSelectedDate() {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = allEntries.first(where: { $0.date == day && $0.source == "manual" }) {
            flowLevel = existing.flowLevel
            symptomsSet = Set(existing.symptoms)
        } else {
            flowLevel = 0
            symptomsSet = []
        }
    }

    private func save() {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = allEntries.first(where: { $0.date == day && $0.source == "manual" }) {
            existing.flowLevel = flowLevel
            existing.symptoms = Array(symptomsSet).sorted()
        } else {
            let entry = SDCycleEntry(
                date: day,
                flowLevel: flowLevel,
                symptoms: Array(symptomsSet).sorted(),
                source: "manual"
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        router.closeModal()
    }
}
