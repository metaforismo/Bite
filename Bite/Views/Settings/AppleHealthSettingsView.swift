import SwiftUI

struct AppleHealthSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Invia calorie", isOn: Bindable(vm).draftProfile.healthSendCalories)
                Toggle("Invia macronutrienti", isOn: Bindable(vm).draftProfile.healthSendMacros)
            } header: {
                Text("Scrittura dati")
            }

            Section {
                Toggle("Calorie bruciate", isOn: Bindable(vm).draftProfile.healthReadBurnedCalories)
                Toggle("Energia a riposo", isOn: Bindable(vm).draftProfile.healthReadRestingEnergy)
                Toggle("Passi", isOn: Bindable(vm).draftProfile.healthReadSteps)
                Toggle("Allenamenti", isOn: Bindable(vm).draftProfile.healthReadWorkouts)
            } header: {
                Text("Lettura dati")
            }

            Section {
                Button {
                    // Open Health app
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("Non vedi i dati? Apri Apple Health")
                    }
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}
