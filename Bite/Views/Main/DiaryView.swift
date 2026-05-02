import SwiftUI
import PhotosUI

struct DiaryView: View {
    @Bindable var vm: DiaryViewModel
    var userProfile: UserProfile

    @FocusState private var inputFocused: Bool
    @State private var showDayDetail = false
    @State private var showDatePicker = false
    @State private var showSavedFoods = false
    @State private var showCameraConfirmation = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var speechService = SpeechService()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                List {
                    Section {
                        dateNavigationBar
                            .padding(.bottom, 0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    Section {
                        ForEach(vm.currentLog.entries) { entry in
                            FoodRowView(
                                entry: entry,
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.deleteEntry(entry)
                                    }
                                },
                                onCorrect: { correction in
                                    Task { await vm.correctEntry(entry, correction: correction) }
                                },
                                onToggleSaved: {
                                    vm.toggleSaved(entry)
                                },
                                onRetry: {
                                    Task { await vm.retryEntry(entry) }
                                },
                                onManualEdit: { nutrition, text in
                                    vm.manualEditEntry(entry, nutrition: nutrition, text: text)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    withAnimation { vm.deleteEntry(entry) }
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }

                                Button {
                                    vm.toggleSaved(entry)
                                } label: {
                                    Label(
                                        entry.isSaved ? "Rimuovi" : "Salva",
                                        systemImage: entry.isSaved ? "bookmark.slash" : "bookmark"
                                    )
                                }
                                .tint(Color.biteBlue)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .transition(.opacity.combined(with: .slide))
                        }

                        inlineInputField
                            .id("inputField")
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .animation(.easeInOut(duration: 0.2), value: vm.currentLog.entries.count)

                    // Space for bottom bars
                    Section {
                        Color.clear.frame(height: 140)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await vm.loadDay()
                }
                .onChange(of: vm.currentLog.entries.count) {
                    withAnimation {
                        proxy.scrollTo("inputField", anchor: .bottom)
                    }
                }
            }

            // Bottom overlay
            VStack(spacing: 8) {
                // Floating buttons (bottom-right)
                HStack {
                    Spacer()
                    floatingButtons
                }
                .padding(.horizontal, 16)

                DailySummaryBar(
                    profile: userProfile,
                    log: vm.currentLog,
                    onLongPress: { showDayDetail = true }
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            // Undo toast
            if vm.showUndoToast {
                undoToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            // Error banner
            if vm.showError, let message = vm.errorMessage {
                errorBanner(message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .background(Color.biteBackground)
        .task {
            await vm.loadDay()
        }
        .animation(.easeInOut(duration: 0.25), value: vm.showError)
        .animation(.easeInOut(duration: 0.25), value: vm.showUndoToast)
        .sheet(isPresented: $showDayDetail) {
            DayDetailSheet(profile: userProfile, log: vm.currentLog)
        }
        .sheet(isPresented: $showSavedFoods) {
            SavedFoodsSheet(vm: vm)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await vm.addPhotoEntry(image: image) }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await vm.addPhotoEntry(image: image)
                }
                selectedPhotoItem = nil
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationBar: some View {
        HStack {
            Button {
                Task { await vm.changeDate(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                showDatePicker = true
            } label: {
                Text(vm.selectedDate.shortFormatted)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePicker(
                    "Seleziona data",
                    selection: Binding(
                        get: { vm.selectedDate },
                        set: { newDate in
                            showDatePicker = false
                            Task { await vm.changeDate(to: newDate) }
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "it_IT"))
                .padding()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }

            Spacer()

            Button {
                Task { await vm.changeDate(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.top, 8)
    }

    // MARK: - Inline Input Field (Notes style)

    private var inlineInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Suggestions
            if !vm.filteredSuggestions.isEmpty && !vm.inputText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.filteredSuggestions) { suggestion in
                            Button {
                                vm.addSavedEntry(suggestion)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(suggestion.text)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let kcal = suggestion.nutrition?.calories {
                                        Text("\(kcal) kcal")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.biteRed.opacity(0.1), in: .capsule)
                                .foregroundStyle(Color.biteRed)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Scrivi cosa hai mangiato...", text: $vm.inputText)
                    .font(.body)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await vm.addFoodEntry()
                            inputFocused = true
                        }
                    }

                // Mic button
                Button {
                    toggleSpeech()
                } label: {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.body)
                        .foregroundStyle(speechService.isRecording ? Color.biteRed : .secondary)
                }

                if vm.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .padding(.top, vm.currentLog.entries.isEmpty ? 0 : 10)
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        HStack(spacing: 12) {
            // Camera button
            Button {
                showCameraConfirmation = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15))
                    .frame(width: 36, height: 36)
            }
            .glassEffect(.regular, in: .circle)
            .confirmationDialog("Add photo", isPresented: $showCameraConfirmation) {
                Button("Scatta foto") {
                    showCamera = true
                }
                Button("Scegli dalla galleria") {
                    showPhotoPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }

            // Bookmark button
            Button {
                showSavedFoods = true
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 15))
                    .frame(width: 36, height: 36)
            }
            .glassEffect(.regular, in: .circle)
        }
    }

    // MARK: - Undo Toast

    private var undoToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("Cibo eliminato")
                    .font(.subheadline)

                Spacer()

                Button("Cancel") {
                    vm.undoDelete()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.biteRed)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Speech

    private func toggleSpeech() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                guard authorized else { return }
                try? speechService.startRecording { text in
                    vm.inputText = text
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.biteOrange)

                Text(message)
                    .font(.subheadline)
                    .lineLimit(2)

                Spacer()

                Button {
                    vm.showError = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }
}

#Preview {
    DiaryView(
        vm: DiaryViewModel(),
        userProfile: .default
    )
}
