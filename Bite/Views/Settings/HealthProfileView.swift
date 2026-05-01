import SwiftUI

struct HealthProfileView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section("Genere") {
                Picker("Genere", selection: Bindable(vm).draftProfile.gender) {
                    Text("Non specificato").tag(nil as Gender?)
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender as Gender?)
                    }
                }
            }

            Section("Misure") {
                HStack {
                    Label("Età", systemImage: "calendar")
                    Spacer()
                    TextField("—", text: Binding(
                        get: { vm.draftProfile.age.map(String.init) ?? "" },
                        set: { vm.draftProfile.age = Int($0) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("anni")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack {
                    Label("Altezza", systemImage: "ruler")
                    Spacer()
                    TextField("—", text: Binding(
                        get: { vm.draftProfile.heightCm.map { String(format: "%.0f", $0) } ?? "" },
                        set: { vm.draftProfile.heightCm = Double($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("cm")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack {
                    Label("Peso", systemImage: "scalemass")
                    Spacer()
                    TextField("—", text: Binding(
                        get: { vm.draftProfile.weightKg.map { String(format: "%.1f", $0) } ?? "" },
                        set: { vm.draftProfile.weightKg = Double($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("kg")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            Section("Livello attività") {
                Picker("Attività", selection: Bindable(vm).draftProfile.activityLevel) {
                    Text("Non specificato").tag(nil as ActivityLevel?)
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.rawValue)
                        }
                        .tag(level as ActivityLevel?)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Profilo salute")
        .navigationBarTitleDisplayMode(.inline)
    }
}
