import SwiftUI
import Charts

struct WeightTrackingView: View {
    @Bindable var vm: SettingsViewModel
    @State private var showAddWeight = false
    @State private var newWeightText = ""
    @State private var range: Range = .month

    enum Range: String, CaseIterable, Identifiable {
        case week, month, quarter
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: return "7d"
            case .month: return "30d"
            case .quarter: return "90d"
            }
        }
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }

    private var rangeEntries: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
        return vm.weightEntries.filter { $0.date >= cutoff }
    }

    private var rangeDelta: Double? {
        let entries = rangeEntries
        guard let first = entries.first, let last = entries.last, first.id != last.id else { return nil }
        return last.weightKg - first.weightKg
    }

    private var deltaTint: Color {
        guard let delta = rangeDelta else { return .biteInkFaint }
        if abs(delta) < 0.1 { return .biteInkFaint }
        // Approaching target → green; moving away → red.
        if let target = vm.draftProfile.targetWeightKg, let current = vm.lastWeight {
            let prevDistance = abs(current - delta - target)
            let currentDistance = abs(current - target)
            return currentDistance < prevDistance ? .biteRingRecovery : .biteRed
        }
        return .biteInkFaint
    }

    var body: some View {
        List {
            // Current weight + delta callout
            Section {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let weight = vm.lastWeight {
                            Text(String(format: "%.1f kg", weight))
                                .font(.title)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                        } else {
                            Text("—")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let delta = rangeDelta {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Δ \(range.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.1f kg", delta))
                                .font(.headline)
                                .fontDesign(.rounded)
                                .foregroundStyle(deltaTint)
                        }
                    }
                }
            }

            // Range tabs
            Section {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Chart
            if rangeEntries.count >= 2 {
                Section {
                    Chart {
                        ForEach(rangeEntries) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weightKg)
                            )
                            .foregroundStyle(Color.biteRed)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weightKg)
                            )
                            .foregroundStyle(Color.biteRed)
                        }
                        if let target = vm.draftProfile.targetWeightKg {
                            RuleMark(y: .value("Target", target))
                                .foregroundStyle(Color.biteRingRecovery.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .annotation(position: .topTrailing, alignment: .trailing) {
                                    Text(String(format: "Target %.1f kg", target))
                                        .font(.caption2)
                                        .foregroundStyle(.biteRingRecovery)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.biteRingRecovery.opacity(0.12), in: Capsule())
                                }
                        }
                    }
                    .frame(height: 200)
                } header: {
                    Text("Trend")
                }
            }

            // History
            Section {
                ForEach(vm.weightEntries.reversed()) { entry in
                    HStack {
                        Text(entry.date.shortFormatted)
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f kg", entry.weightKg))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .fontDesign(.rounded)
                    }
                }
            } header: {
                Text("History")
            }
        }
        .navigationTitle("Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddWeight = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add weight", isPresented: $showAddWeight) {
            TextField("Weight in kg", text: $newWeightText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {
                newWeightText = ""
            }
            Button("Save") {
                if let weight = Double(newWeightText) {
                    vm.addWeightEntry(kg: weight)
                }
                newWeightText = ""
            }
        }
    }
}
