import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(BiteRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\SDFoodEntry.createdAt, order: .forward)])
    private var foodEntries: [SDFoodEntry]
    @Query(sort: [SortDescriptor(\SDDrinkEntry.timestamp, order: .forward)])
    private var drinkEntries: [SDDrinkEntry]
    @Query(sort: [SortDescriptor(\SDCycleEntry.date, order: .forward)])
    private var cycleEntries: [SDCycleEntry]
    @Query(sort: [SortDescriptor(\SDJournalEntry.date, order: .forward)])
    private var journalEntries: [SDJournalEntry]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var quickAddOpen = false
    @State private var editingKind: JournalContributorKind?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BiteTopBar(onBack: nil) { EmptyView() }
                header
                dayStrip
                scoreStrip
                quickAddBar
                contributorInsightCard
                contributorGroups
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $quickAddOpen) {
            ContributorQuickAddSheet(
                onFood: {
                    quickAddOpen = false
                    router.openChat(prefill: "Log a meal for my journal.")
                },
                onWater: {
                    quickAddOpen = false
                    router.openModal(.hydration)
                },
                onCaffeine: {
                    quickAddOpen = false
                    router.openModal(.caffeine)
                },
                onCycle: {
                    quickAddOpen = false
                    router.openModal(.menstrualLog)
                },
                onGeneric: { kind in
                    quickAddOpen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        editingKind = kind
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingKind) { kind in
            GenericContributorEntrySheet(kind: kind, date: selectedDate) { entry in
                modelContext.insert(entry)
                try? modelContext.save()
                editingKind = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Journal")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(selectedDate, format: .dateTime.month(.wide).day().year())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }
            Spacer()
            Button {
                router.openChat(prefill: "Analyze my journal contributors for patterns and correlations.")
            } label: {
                Label("Insights", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.96))
        }
        .padding(.horizontal, 20)
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(daysForStrip, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let hasData = !items(on: day).isEmpty
                    Button {
                        BiteHaptics.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selectedDate = calendar.startOfDay(for: day)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(day, format: .dateTime.weekday(.narrow))
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(selected ? .white : .biteInkFaint)
                            Text(day, format: .dateTime.day())
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(selected ? .white : .biteInk)
                            Circle()
                                .fill(hasData ? (selected ? Color.white : Color.biteRed) : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(width: 48, height: 72)
                        .background(selected ? Color.biteInk : Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.black.opacity(selected ? 0 : 0.05), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var scoreStrip: some View {
        let todayItems = items(on: selectedDate)
        let foodKcal = foodItems(on: selectedDate).compactMap(\.nutrition?.calories).reduce(0, +)
        let caffeine = drinkEntries(on: selectedDate, kind: .caffeine).compactMap(\.caffeineMg).reduce(0, +)
        let water = drinkEntries(on: selectedDate, kind: .water).compactMap(\.volumeML).reduce(0, +)

        return HStack(spacing: 10) {
            JournalStatTile(label: "Entries", value: "\(todayItems.count)", tint: .biteInk)
            JournalStatTile(label: "Kcal", value: "\(foodKcal)", tint: .biteRed)
            JournalStatTile(label: "Water", value: "\(Int(water)) ml", tint: .biteHydration)
            JournalStatTile(label: "Caffeine", value: "\(Int(caffeine)) mg", tint: .biteCarbs)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var contributorGroups: some View {
        let grouped = Dictionary(grouping: items(on: selectedDate), by: \.group)
        if grouped.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(["Nutrition", "Hydration", "Signals", "Cycle", "Notes"], id: \.self) { group in
                    if let entries = grouped[group], !entries.isEmpty {
                        JournalGroupSection(title: group, items: entries)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.biteRed)
                .frame(width: 58, height: 58)
                .background(Color.biteRed.opacity(0.12), in: Circle())
            Text("No contributors yet")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.biteInk)
            Text("Add food, caffeine, hydration, symptoms, supplements, or a quick note.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Button {
                BiteHaptics.impact(.light)
                quickAddOpen = true
            } label: {
                Label("Add contributor", systemImage: "plus")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.biteInk, in: Capsule())
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.97))

            Button {
                router.openChat(prefill: "What patterns do you see in my recent journal entries?")
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.biteInk)
                    .frame(width: 46, height: 46)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.94))
        }
        .padding(.horizontal, 20)
    }

    private var contributorInsightCard: some View {
        let foodCount = foodItems(on: selectedDate).count
        let caffeine = drinkEntries(on: selectedDate, kind: .caffeine).compactMap(\.caffeineMg).reduce(0, +)
        let water = drinkEntries(on: selectedDate, kind: .water).compactMap(\.volumeML).reduce(0, +)
        let alcohol = journalEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.kind == .alcohol }.count
        let symptoms = journalEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) && ($0.kind == .symptom || $0.kind == .stress) }.count
        let hydrationProgress = min(1, water / 2_500)
        let stimulantLoad = min(1, caffeine / 400)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTRIBUTOR IMPACT")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(.biteInkFaint)
                    Text("What may move recovery")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.biteInk)
                }
                Spacer()
                Button {
                    router.openChat(prefill: "Correlate my journal contributors with recovery, sleep, digestion, and training.")
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.biteInk)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                JournalInsightRow(
                    title: "Fuel consistency",
                    subtitle: foodCount == 0 ? "No meals logged" : "\(foodCount) logged meal\(foodCount == 1 ? "" : "s")",
                    value: foodCount == 0 ? 0.12 : min(1, Double(foodCount) / 4.0),
                    tint: .biteRed
                )
                JournalInsightRow(
                    title: "Hydration coverage",
                    subtitle: "\(Int(water)) ml today",
                    value: hydrationProgress,
                    tint: .biteHydration
                )
                JournalInsightRow(
                    title: "Stimulant load",
                    subtitle: caffeine == 0 ? "No caffeine logged" : "\(Int(caffeine)) mg caffeine",
                    value: stimulantLoad,
                    tint: stimulantLoad > 0.65 ? .biteWarning : .biteCarbs
                )
                JournalInsightRow(
                    title: "Recovery friction",
                    subtitle: "\(symptoms) symptom/stress · \(alcohol) alcohol",
                    value: min(1, Double(symptoms + alcohol) / 4.0),
                    tint: symptoms + alcohol == 0 ? .biteRingRecovery : .biteRed
                )
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var daysForStrip: [Date] {
        (-3...10).compactMap { calendar.date(byAdding: .day, value: $0, to: Date()) }
    }

    private func items(on date: Date) -> [JournalTimelineItem] {
        let foods = foodItems(on: date).map { entry in
            JournalTimelineItem(
                group: "Nutrition",
                icon: "fork.knife",
                tint: .biteRed,
                title: entry.text,
                detail: entry.nutrition.map { "\($0.calories) kcal · \(Int($0.protein))g protein" } ?? "Food entry",
                time: entry.createdAt
            )
        }
        let drinks = drinkEntries(on: date, kind: nil).map { entry in
            JournalTimelineItem(
                group: entry.kind == .water ? "Hydration" : "Signals",
                icon: entry.kind == .water ? "drop.fill" : "cup.and.saucer.fill",
                tint: entry.kind == .water ? .biteHydration : .biteCarbs,
                title: entry.kind.displayName,
                detail: drinkDetail(entry),
                time: entry.timestamp
            )
        }
        let cycles = cycleEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }.map { entry in
            JournalTimelineItem(
                group: "Cycle",
                icon: "calendar.badge.clock",
                tint: .biteRedSoft,
                title: "Cycle",
                detail: cycleDetail(entry),
                time: entry.date
            )
        }
        let generic = journalEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }.map { entry in
            JournalTimelineItem(
                group: entry.kind == .note ? "Notes" : "Signals",
                icon: icon(for: entry.kind),
                tint: tint(for: entry.kind),
                title: entry.kind.displayName,
                detail: entryDetail(entry),
                time: entry.date
            )
        }
        return (foods + drinks + cycles + generic).sorted { $0.time < $1.time }
    }

    private func foodItems(on date: Date) -> [FoodEntry] {
        foodEntries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map { $0.toStruct() }
    }

    private func drinkEntries(on date: Date, kind: DrinkKind?) -> [SDDrinkEntry] {
        drinkEntries.filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: date) && (kind == nil || entry.kind == kind)
        }
    }

    private func drinkDetail(_ entry: SDDrinkEntry) -> String {
        if entry.kind == .water {
            return "\(Int(entry.volumeML ?? 0)) ml"
        }
        return "\(entry.label ?? "Caffeine") · \(Int(entry.caffeineMg ?? 0)) mg"
    }

    private func cycleDetail(_ entry: SDCycleEntry) -> String {
        let flow: String
        switch entry.flowLevel {
        case 1: flow = "Light flow"
        case 2: flow = "Medium flow"
        case 3: flow = "Heavy flow"
        default: flow = "No flow"
        }
        return entry.symptoms.isEmpty ? flow : "\(flow) · \(entry.symptoms.joined(separator: ", "))"
    }

    private func entryDetail(_ entry: SDJournalEntry) -> String {
        let value = entry.value.map { value in
            let formatted = value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
            return "\(formatted)\(entry.unit.map { " \($0)" } ?? "")"
        }
        return [value, entry.note.isEmpty ? nil : entry.note].compactMap { $0 }.joined(separator: " · ")
    }

    private func icon(for kind: JournalContributorKind) -> String {
        switch kind {
        case .alcohol: return "wineglass.fill"
        case .symptom: return "cross.case.fill"
        case .medication: return "pills.fill"
        case .supplement: return "leaf.fill"
        case .note: return "note.text"
        case .mood: return "face.smiling"
        case .stress: return "waveform.path.ecg"
        }
    }

    private func tint(for kind: JournalContributorKind) -> Color {
        switch kind {
        case .alcohol: return .biteRed
        case .symptom, .stress: return .biteWarning
        case .medication: return .biteHydration
        case .supplement: return .biteFiber
        case .note: return .biteInkMuted
        case .mood: return .biteFat
        }
    }
}

private struct JournalTimelineItem: Identifiable {
    let id = UUID()
    let group: String
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    let time: Date
}

private struct JournalStatTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.biteInkFaint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
    }
}

private struct JournalGroupSection: View {
    let title: String
    let items: [JournalTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.tint)
                            .frame(width: 34, height: 34)
                            .background(item.tint.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.biteInk)
                                .lineLimit(1)
                            Text(item.detail)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.biteInkMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(item.time, format: .dateTime.hour().minute())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.biteInkFaint)
                            .monospacedDigit()
                    }
                    .padding(12)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
    }
}

private struct JournalInsightRow: View {
    let title: String
    let subtitle: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.055))
                    .frame(height: 7)
                Capsule()
                    .fill(tint)
                    .frame(width: max(10, CGFloat(value) * 92), height: 7)
            }
            .frame(width: 92)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

private struct ContributorQuickAddSheet: View {
    let onFood: () -> Void
    let onWater: () -> Void
    let onCaffeine: () -> Void
    let onCycle: () -> Void
    let onGeneric: (JournalContributorKind) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add contributor")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.biteInk)
                .padding(.top, 18)
                .padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 4) {
                    row("Food", "Meal, snack, or photo log", "fork.knife", .biteRed, onFood)
                    row("Water", "Hydration entry", "drop.fill", .biteHydration, onWater)
                    row("Caffeine", "Coffee, tea, energy drinks", "cup.and.saucer.fill", .biteCarbs, onCaffeine)
                    row("Cycle", "Flow and symptoms", "calendar.badge.clock", .biteRedSoft, onCycle)
                    row("Alcohol", "Drinks and timing", "wineglass.fill", .biteRed) { onGeneric(.alcohol) }
                    row("Symptom", "Severity and note", "cross.case.fill", .biteWarning) { onGeneric(.symptom) }
                    row("Medication", "Dose or timing", "pills.fill", .biteHydration) { onGeneric(.medication) }
                    row("Supplement", "Dose or timing", "leaf.fill", .biteFiber) { onGeneric(.supplement) }
                    row("Note", "Anything worth remembering", "note.text", .biteInkMuted) { onGeneric(.note) }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .background(Color.white)
    }

    private func row(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.biteInk)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteInkFaint)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
    }
}

private struct GenericContributorEntrySheet: View {
    let kind: JournalContributorKind
    let date: Date
    let onSave: (SDJournalEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String = ""
    @State private var note: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.displayName)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInk)
                    Text("Add to journal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.biteInk)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if kind != .note {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Value")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.biteInkMuted)
                    HStack {
                        TextField("Optional", text: $value)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold))
                        Text(kind.defaultUnit)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.biteInkMuted)
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Note")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.biteInkMuted)
                TextField(kind == .note ? "Write a note" : "Optional context", text: $note, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(14)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Spacer()

            Button {
                let parsedValue = Double(value.replacingOccurrences(of: ",", with: "."))
                let entry = SDJournalEntry(
                    kind: kind,
                    date: date,
                    value: parsedValue,
                    unit: kind.defaultUnit.isEmpty ? nil : kind.defaultUnit,
                    note: note
                )
                onSave(entry)
            } label: {
                Text("Add to journal")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.biteInk, in: Capsule())
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
        }
        .padding(20)
        .background(Color.white)
    }
}
