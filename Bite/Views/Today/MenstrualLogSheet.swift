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
                    cycleWheel
                    dateField
                    flowField
                    symptomsField
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: 620)
            .onAppear { hydrateForToday() }
        }
    }

    /// Cycle wheel — uses OrbitDial repurposed as a 4-phase ring
    /// (menstruation/follicular/ovulation/luteal). Today's phase is
    /// indicated by a glowing dot at the right offset; cycle day
    /// number sits at the center.
    private var cycleWheel: some View {
        let info = currentCycleInfo()

        // Map a 28-day cycle onto the dial's 24h coordinate system —
        // each phase becomes a colored arc band.
        let arcs: [DialArc] = [
            DialArc(startAngle: 0,   endAngle: 64,  color: Color(hex: 0xE63C5E), width: 14, inset: 14), // menstruation
            DialArc(startAngle: 64,  endAngle: 192, color: Color(hex: 0xFF93AD), width: 14, inset: 14), // follicular
            DialArc(startAngle: 192, endAngle: 232, color: Color(hex: 0xFFB7C9), width: 14, inset: 14), // ovulation
            DialArc(startAngle: 232, endAngle: 360, color: Color(hex: 0xC97898), width: 14, inset: 14), // luteal
        ]

        let dotAngle: Double = 360.0 * Double(info.dayInCycle - 1) / 28.0
        let indicators: [DialIndicator] = [
            DialIndicator(angle: dotAngle, color: Color(hex: 0xE63C5E), size: 24, inset: 14, systemImage: "drop.fill", glow: true)
        ]

        return OrbitDial(theme: .cycle, arcs: arcs, indicators: indicators) {
            VStack(spacing: 2) {
                Text("Day \(info.dayInCycle)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(info.phaseLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: 0xC72E2E))
            }
        }
        .frame(maxWidth: 240, maxHeight: 240)
        .padding(.bottom, 6)
    }

    private struct CycleInfo {
        let dayInCycle: Int
        let phaseLabel: String
    }

    private func currentCycleInfo() -> CycleInfo {
        // Use the most-recent menstruation start as anchor, or default
        // to "Day 1" when no history exists yet.
        let lastFlow = allEntries.first(where: { $0.flowLevel >= 1 })
        let referenceDay = Calendar.current.startOfDay(for: date)
        guard let start = lastFlow?.date else {
            return CycleInfo(dayInCycle: 1, phaseLabel: "Menstruation")
        }
        let days = max(0, Calendar.current.dateComponents([.day], from: start, to: referenceDay).day ?? 0)
        let dayInCycle = (days % 28) + 1

        let phase: String
        switch dayInCycle {
        case 1...5:   phase = "Menstruation"
        case 6...13:  phase = "Follicular"
        case 14...16: phase = "Ovulation"
        default:      phase = "Luteal"
        }
        return CycleInfo(dayInCycle: dayInCycle, phaseLabel: phase)
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
