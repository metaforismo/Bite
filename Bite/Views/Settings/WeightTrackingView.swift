import SwiftUI
import Charts

struct WeightTrackingView: View {
    @Bindable var vm: SettingsViewModel
    @State private var showAddWeight = false
    @State private var newWeightText = ""

    var body: some View {
        List {
            // Current weight section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Peso attuale")
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
                    if let change = vm.monthlyWeightChange {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Ultimo mese")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.1f kg", change))
                                .font(.headline)
                                .fontDesign(.rounded)
                                .foregroundStyle(change < 0 ? .green : change > 0 ? .orange : .secondary)
                        }
                    }
                }
            }

            // Chart
            if vm.weightEntries.count >= 2 {
                Section {
                    Chart(vm.weightEntries) { entry in
                        LineMark(
                            x: .value("Data", entry.date),
                            y: .value("Peso", entry.weightKg)
                        )
                        .foregroundStyle(Color.biteRed)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Data", entry.date),
                            y: .value("Peso", entry.weightKg)
                        )
                        .foregroundStyle(Color.biteRed)
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
                Text("Storico")
            }
        }
        .navigationTitle("Peso")
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
        .alert("Aggiungi peso", isPresented: $showAddWeight) {
            TextField("Peso in kg", text: $newWeightText)
                .keyboardType(.decimalPad)
            Button("Annulla", role: .cancel) {
                newWeightText = ""
            }
            Button("Salva") {
                if let weight = Double(newWeightText) {
                    vm.addWeightEntry(kg: weight)
                }
                newWeightText = ""
            }
        }
    }
}
