import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import SwiftData

struct PlusSheet: View {
    @Bindable var router: BiteRouter
    @Environment(\.modelContext) private var modelContext

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingFilePicker: Bool = false
    @State private var showingLabPicker: Bool = false
    @State private var uploading: Bool = false
    @State private var error: String?

    enum Action {
        case addFiles, healthCheckIn, screenContext, logFood, trainingPlan, impactAnalysis, predictive, labReport
    }

    private struct Item: Identifiable {
        let id = UUID()
        let systemImage: String
        let label: String
        let sub: String
        let action: Action
    }

    private let items: [Item] = [
        .init(systemImage: "paperclip", label: "Add files", sub: "Upload photos, docs, or labs", action: .addFiles),
        .init(systemImage: "heart.fill", label: "Health check-in", sub: "Log how you feel", action: .healthCheckIn),
        .init(systemImage: "rectangle.dashed", label: "Screen context", sub: "Share what you're looking at", action: .screenContext),
        .init(systemImage: "fork.knife", label: "Log food", sub: "Track a meal or ingredient", action: .logFood),
        .init(systemImage: "figure.run", label: "Training plan", sub: "Build or adjust your plan", action: .trainingPlan),
        .init(systemImage: "chart.bar.fill", label: "Impact analysis", sub: "See what's driving you", action: .impactAnalysis),
        .init(systemImage: "chart.line.uptrend.xyaxis", label: "Predictive modeling", sub: "Forecast your progress", action: .predictive),
        .init(systemImage: "testtube.2", label: "Lab report", sub: "Upload and analyze labs", action: .labReport),
    ]

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            photoStrip
            list
            if uploading {
                ProgressView("Uploading…")
                    .padding(.bottom, 12)
            }
            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.biteRed)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .photosPicker(isPresented: .constant(false), selection: $pickerItem, matching: .images)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            handle(fileImport: result, isLab: false)
        }
        .fileImporter(isPresented: $showingLabPicker, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            handle(fileImport: result, isLab: true)
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task { await handlePhotoPick(newValue) }
        }
    }

    private var handle: some View {
        Capsule()
            .fill(Color(hex: 0xE5E5EA))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("Add to chat")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.biteInk)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button { router.closePlusSheet() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0xF0EFEE), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {} label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0xF0EFEE))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.biteInkMuted)
                    }
                    .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(samplePattern(for: i))
                        .frame(width: 70, height: 70)
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.vertical, 14)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    handle(action: item.action)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.biteRedTint)
                            Image(systemName: item.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.biteRed)
                        }
                        .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.biteInk)
                            Text(item.sub)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.biteInkFaint)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 24)
    }

    // MARK: Actions

    private func handle(action: Action) {
        switch action {
        case .addFiles:
            showingFilePicker = true
        case .labReport:
            showingLabPicker = true
        case .logFood:
            router.closePlusSheet()
            router.prefilledChatPrompt = "Log my last meal"
        case .healthCheckIn:
            router.closePlusSheet()
            router.prefilledChatPrompt = "How are you feeling? Log a quick health check-in for me."
        case .screenContext:
            router.closePlusSheet()
        case .trainingPlan:
            router.closePlusSheet()
            router.prefilledChatPrompt = "Build me a 4-week training plan"
        case .impactAnalysis:
            router.closePlusSheet()
            router.prefilledChatPrompt = "Run an impact analysis on my recovery this week"
        case .predictive:
            router.closePlusSheet()
            router.prefilledChatPrompt = "Forecast my HRV and sleep for the next 7 days"
        }
    }

    private func handle(fileImport: Result<[URL], Error>, isLab: Bool) {
        do {
            let urls = try fileImport.get()
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let kind: FileKind = url.pathExtension.lowercased() == "pdf" ? .pdf : .image
            uploadAndAnalyze(data: data, kind: kind, displayName: url.lastPathComponent)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                uploadAndAnalyze(data: data, kind: .image, displayName: "photo.jpg")
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func uploadAndAnalyze(data: Data, kind: FileKind, displayName: String) {
        uploading = true
        error = nil
        Task { @MainActor in
            defer { uploading = false }
            do {
                let api = BiteAPIClient(auth: AuthService.shared)
                let svc = FileUploadService(api: api)
                let file = try await svc.upload(data: data, kind: kind, displayName: displayName, in: modelContext)
                _ = try await svc.analyze(fileId: file.id)
                router.closePlusSheet()
                router.prefilledChatPrompt = "Analyze the file I just uploaded."
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func samplePattern(for index: Int) -> Color {
        let colors = [
            Color(hex: 0xF4A532),
            Color(hex: 0x92C77E),
            Color(hex: 0xFF9F8C),
            Color(hex: 0x8BB4E8),
        ]
        return colors[index % colors.count]
    }
}
