import SwiftUI
import SwiftData

struct CoachView: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @State private var input: String = ""
    @State private var chat: CoachChatViewModel?

    private var orbState: OrbState {
        guard let chat else { return .idle }
        switch chat.mode {
        case .thinking: return .thinking
        case .listening: return .listening
        case .response: return .speaking
        case .error: return .error
        default: return .idle
        }
    }

    private var orbMood: OrbMood {
        guard let chat else { return .neutral }
        switch chat.mode {
        case .thinking: return .think
        case .listening: return .listen
        case .response: return .happy
        default: return .neutral
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            transcriptScroll
            quickActions
            composer
        }
        .padding(.top, BiteTheme.topPadding)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if chat == nil {
                let api = BiteAPIClient(auth: AuthService.shared)
                let remote = RemoteAIService(api: api)
                chat = CoachChatViewModel(modelContext: modelContext, remote: remote, auth: AuthService.shared)
            }
        }
        .onChange(of: router.prefilledChatPrompt) { _, value in
            if let value, !value.isEmpty { input = value }
        }
    }

    private var header: some View {
        HStack {
            Button { router.toggleDrawer() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            if shouldShowMiniOrbInHeader {
                VStack(spacing: 2) {
                    BiteOrbImage(size: 32, mood: orbMood, state: orbState, showHalo: false)
                    Text("New chat")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInk)
                }
            }
            Spacer()
            Button { router.closeOverlay() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var shouldShowMiniOrbInHeader: Bool {
        guard let chat else { return false }
        switch chat.mode {
        case .idle, .listening: return false
        default: return true
        }
    }

    @ViewBuilder
    private var transcriptScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if chat?.mode == .idle || chat == nil {
                    heroOrb
                } else {
                    transcript
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heroOrb: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            BiteOrbImage(size: 130, mood: orbMood, state: orbState)
            Text(Date(), format: .dateTime.weekday(.abbreviated).month().day())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.biteInkFaint)
                .padding(.top, 6)
            Text("What should we look at?")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(.biteInk)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var transcript: some View {
        if let chat {
            VStack(alignment: .leading, spacing: 14) {
                if let thread = chat.thread {
                    ForEach(sortedMessages(in: thread)) { msg in
                        messageView(for: msg)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                if !chat.thinkingSteps.isEmpty {
                    ThinkingCascade(steps: chat.thinkingSteps)
                }
                if !chat.streamingText.isEmpty, chat.mode == .response {
                    AssistantText(text: chat.streamingText)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let error = chat.lastError, chat.mode == .error {
                    Text("Coach error: \(error)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteRed)
                }
            }
            .animation(BiteMotion.bubbleRise, value: chat.streamingText)
            .animation(BiteMotion.bubbleRise, value: chat.thinkingSteps.count)
        }
    }

    private func sortedMessages(in thread: CoachThread) -> [CoachMessage] {
        thread.messages.sorted { $0.createdAt < $1.createdAt }
    }

    @ViewBuilder
    private func messageView(for message: CoachMessage) -> some View {
        if let artifact = message as? ArtifactMessage {
            ArtifactRouterView(artifact: artifact)
        } else if message.role == .user {
            UserBubble(text: message.text)
        } else {
            AssistantText(text: message.text)
        }
    }

    private var quickActions: some View {
        Group {
            if let chat, chat.mode == .idle {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        QuickActionChip(systemImage: "testtube.2", title: "Analyze labs", sub: "Review your bloodwork in plain English") {
                            input = "Analyze my latest labs"
                        }
                        QuickActionChip(systemImage: "chart.line.uptrend.xyaxis", title: "Predictive modeling", sub: "Forecast HRV, recovery & sleep") {
                            input = "Forecast my metrics for the next 7 days"
                        }
                        QuickActionChip(systemImage: "camera.fill", title: "Log food", sub: "Snap a photo or describe a meal") {
                            input = "Log my lunch"
                        }
                        QuickActionChip(systemImage: "clock", title: "Schedule check-in", sub: "Ask me every morning at 8am") {
                            input = "Schedule a daily check-in"
                        }
                        QuickActionChip(systemImage: "heart.fill", title: "Symptom check", sub: "Describe how you feel right now") {
                            input = "I have a headache and feel tired"
                        }
                        QuickActionChip(systemImage: "figure.run", title: "New training plan", sub: "Personalize for your goals") {
                            input = "Build me a training plan"
                        }
                        QuickActionChip(systemImage: "pin.fill", title: "Goal setting", sub: "Define a target & track progress") {
                            input = "Help me set a new goal"
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 12)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 7) {
            Button {
                router.openPlusSheet()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            TextField("Ask Bite anything", text: $input)
                .font(.system(size: 15))
                .foregroundStyle(.biteInk)
                .submitLabel(.send)
                .onSubmit(submit)

            Button {} label: {
                Image(systemName: "mic")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.biteInkMuted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            if chat?.isStreaming == true {
                Button(action: { chat?.cancelStream() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.biteInk, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(input.isEmpty ? Color(hex: 0xE5E5EA) : .biteRed, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(input.isEmpty)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: BiteTheme.composerHeight)
        .background(Color.white.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 4)
        .glassEffect(in: .capsule)
        .matchedGeometryEffect(id: "composer", in: morphNS)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let chat else { return }
        input = ""
        chat.send(text)
    }
}

struct QuickActionChip: View {
    let systemImage: String
    let title: String
    let sub: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.biteRedTint)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.biteRed)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.biteInk)
                    Text(sub)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(width: 156, height: 110, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}
