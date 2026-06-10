import SwiftUI

struct AppleHealthSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Send calories", isOn: Bindable(vm).draftProfile.healthSendCalories)
                Toggle("Send macronutrients", isOn: Bindable(vm).draftProfile.healthSendMacros)
            } header: {
                Text("Write data")
            }

            Section {
                Toggle("Active calories", isOn: Bindable(vm).draftProfile.healthReadBurnedCalories)
                Toggle("Resting energy", isOn: Bindable(vm).draftProfile.healthReadRestingEnergy)
                Toggle("Steps", isOn: Bindable(vm).draftProfile.healthReadSteps)
                Toggle("Workouts", isOn: Bindable(vm).draftProfile.healthReadWorkouts)
            } header: {
                Text("Read data")
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
                        Text("Not seeing your data? Open Apple Health")
                    }
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}
