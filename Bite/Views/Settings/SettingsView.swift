import SwiftUI

struct SettingsView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.openURL) private var openURL
    @State private var vm: SettingsViewModel?
    @State private var showExportShare = false
    @State private var exportData: Data?

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if let vm {
                    settingsContent(vm: vm)
                        .onChange(of: vm.draftProfile) {
                            vm.debounceSave()
                        }
                }

                if vm?.showSavedToast == true {
                    savedToast
                }
            }
        }
        .onAppear {
            if vm == nil {
                let settingsVM = SettingsViewModel(profile: userProfile)
                settingsVM.onProfileUpdate = { newProfile in
                    userProfile = newProfile
                }
                vm = settingsVM
            } else {
                vm?.draftProfile = userProfile
            }
        }
    }

    @ViewBuilder
    private func settingsContent(vm: SettingsViewModel) -> some View {
        Form {
            // 1. Profile
            Section("Profile") {
                HStack {
                    Label("Name", systemImage: "person.fill")
                    Spacer()
                    TextField("Your name", text: Bindable(vm).draftProfile.name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("Email", systemImage: "envelope.fill")
                    Spacer()
                    TextField("Your email", text: Bindable(vm).draftProfile.email)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            // 2. Goals & Targets
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if let tdee = vm.dailyBurn {
                        HStack {
                            Text("Estimated TDEE")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(tdee) kcal/day")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    HStack(spacing: 16) {
                        goalMini(value: "\(vm.draftProfile.calorieGoal)", label: "Cal", color: .biteOrange)
                        goalMini(value: String(format: "%.0f", vm.draftProfile.proteinGoal), label: "Pro", color: .biteBlue)
                        goalMini(value: String(format: "%.0f", vm.draftProfile.carbsGoal), label: "Carb", color: .biteOrange)
                        goalMini(value: String(format: "%.0f", vm.draftProfile.fatGoal), label: "Fat", color: .biteRed)
                    }
                }

                NavigationLink {
                    NutritionGoalsView(vm: vm)
                } label: {
                    Label("Nutrition goals", systemImage: "target")
                }
            } header: {
                Text("Goals & Targets")
            }

            // 3. Health Profile
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if let weight = vm.draftProfile.weightKg {
                        HStack {
                            Text("Current weight")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f kg", weight))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    if let activity = vm.draftProfile.activityLevel {
                        HStack {
                            Text("Activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(activity.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }

                NavigationLink {
                    HealthProfileView(vm: vm)
                } label: {
                    Label("Health profile", systemImage: "heart.fill")
                }
            } header: {
                Text("Health Profile")
            }

            // 4. Weight Tracking
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let last = vm.lastWeight {
                            Text(String(format: "%.1f kg", last))
                                .font(.title3)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                        } else {
                            Text("No data")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let change = vm.monthlyWeightChange {
                            Text(String(format: "%+.1f kg this month", change))
                                .font(.caption)
                                .foregroundStyle(change < 0 ? .green : change > 0 ? .orange : .secondary)
                        }
                    }
                    Spacer()
                }

                NavigationLink {
                    WeightTrackingView(vm: vm)
                } label: {
                    Label("Weight history", systemImage: "chart.line.uptrend.xyaxis")
                }
            } header: {
                Text("Weight Tracking")
            }

            // 5. Saved Meals
            Section {
                HStack {
                    Label("Saved meals", systemImage: "bookmark.fill")
                    Spacer()
                    Text("\(vm.savedMealsCount)")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    SavedMealsView(vm: vm)
                } label: {
                    Label("Manage saved", systemImage: "list.bullet")
                }
            } header: {
                Text("Saved Meals")
            }

            // 6. Preferences
            Section {
                Picker("Calorie bias", selection: Bindable(vm).draftProfile.calorieBias) {
                    Text("Not specified").tag(nil as CalorieBias?)
                    ForEach(CalorieBias.allCases, id: \.self) { bias in
                        Text(bias.rawValue).tag(bias as CalorieBias?)
                    }
                }

                Toggle("Use location for restaurants", isOn: Bindable(vm).draftProfile.useLocationForRestaurants)

                Toggle("Daily reminders", isOn: Bindable(vm).draftProfile.dailyRemindersEnabled)

                if vm.draftProfile.dailyRemindersEnabled {
                    Picker("Frequency", selection: Bindable(vm).draftProfile.reminderFrequency) {
                        ForEach(ReminderFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }
            } header: {
                Text("Preferences")
            }

            // 7. Apple Health
            Section {
                Toggle("Enable Apple Health", isOn: Bindable(vm).draftProfile.healthEnabled)

                if vm.draftProfile.healthEnabled {
                    NavigationLink {
                        AppleHealthSettingsView(vm: vm)
                    } label: {
                        Label("Health settings", systemImage: "heart.text.clipboard")
                    }
                }
            } header: {
                Text("Apple Health")
            }

            // 8. Device Settings
            Section {
                Toggle("Automatic time zone", isOn: Bindable(vm).draftProfile.automaticTimeZone)

                Picker("Dictation language", selection: Bindable(vm).draftProfile.dictationLanguage) {
                    ForEach(DictationLanguage.allCases, id: \.self) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
            } header: {
                Text("Device")
            }

            // 9. Subscription
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trial")
                            .font(.headline)
                        Text("Trial version active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Subscription")
            }

            // 10. System Actions
            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Bite", systemImage: "info.circle")
                }

                Button {
                    if let url = URL(string: "mailto:francescogiannicola1@gmail.com?subject=Bite%20Feedback") {
                        openURL(url)
                    }
                } label: {
                    Label("Send feedback", systemImage: "envelope")
                }

                Button {
                    if let url = URL(string: "mailto:francescogiannicola1@gmail.com?subject=Bite%20Support") {
                        openURL(url)
                    }
                } label: {
                    Label("Contact us", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Support")
            }

            Section {
                Button {
                    exportData = vm.exportData()
                    showExportShare = true
                } label: {
                    Label("Export data", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    vm.clearLocalCache()
                } label: {
                    Label("Clear local cache", systemImage: "trash")
                }

                Button(role: .destructive) {
                    vm.deleteAccount()
                } label: {
                    Label("Delete account", systemImage: "person.crop.circle.badge.minus")
                }
            } header: {
                Text("Data")
            }

            // Icon picker
            Section {
                AppIconPicker()
            } header: {
                Text("App Icon")
            }

            // App version
            Section {
                HStack {
                    Label("Version", systemImage: "gear")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showExportShare) {
            if let data = exportData {
                ShareSheet(data: data)
            }
        }
    }

    private func goalMini(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var savedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Saved")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .transition(.move(edge: .top).combined(with: .opacity))
        .padding(.top, 8)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("bite_export.json")
        try? data.write(to: tempURL)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    @Previewable @State var profile = UserProfile.default
    SettingsView(userProfile: $profile)
}
