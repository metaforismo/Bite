import SwiftUI
import SwiftData

struct CoachView: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID
    @Binding var userProfile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\CoachThread.lastMessageAt, order: .reverse)])
    private var allThreads: [CoachThread]

    @State private var input: String = ""
    @State private var chat: CoachChatViewModel?
    @FocusState private var inputFocused: Bool

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

    private var threadCount: Int {
        allThreads.count
    }

    private var greeting: String {
        let trimmed = userProfile.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "What's up?" : "What's up, \(trimmed)?"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, BiteTheme.deviceSafeAreaTop)
            transcriptScroll
            quickActions
            composer
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
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
        BiteTopBar(onBack: nil) {
            HStack {
                Button { router.toggleDrawer() } label: {
                    drawerButtonLabel
                }
                .buttonStyle(.plain)

                Spacer()

                Button { router.closeOverlay() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.biteInk)
                        .frame(
                            width: BiteTheme.topBarButtonSize,
                            height: BiteTheme.topBarButtonSize
                        )
                        .glassEffect(.regular.tint(.white.opacity(0.4)).interactive(), in: .circle)
                        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    private var drawerButtonLabel: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.biteInk)
            .frame(
                width: BiteTheme.topBarButtonSize,
                height: BiteTheme.topBarButtonSize
            )
            .glassEffect(.regular.tint(.white.opacity(0.4)).interactive(), in: .circle)
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if threadCount > 0 {
                    Text("\(threadCount)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.biteRed, in: Capsule())
                        .offset(x: 4, y: -4)
                }
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
            Spacer().frame(height: 24)
            BiteOrbImage(size: 130, mood: orbMood, state: orbState)
            Text(Date(), format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkFaint)
                .padding(.top, 6)
            Text(greeting)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(.biteInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer().frame(height: 12)
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
            if chat?.mode == .idle || chat == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Self.quickActionItems, id: \.title) { item in
                            QuickActionCard(
                                systemImage: item.icon,
                                iconColor: item.color,
                                title: item.title,
                                subtitle: item.subtitle
                            ) {
                                input = item.prefill
                                inputFocused = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }
        }
    }

    /// Static list of starter prompts shown as cards on the Coach idle
    /// screen. Tapping a card pre-fills the composer; the user can edit
    /// before sending. Order is intentional: the two highest-value
    /// actions ("Predictive modeling" and "Log food") sit at indices 0
    /// and 1 so they're visible at rest on a standard iPhone width.
    private static let quickActionItems: [QuickActionItem] = [
        QuickActionItem(
            icon: "chart.line.uptrend.xyaxis",
            color: .biteRingRecovery,
            title: "Predictive modeling",
            subtitle: "Forecast your metrics",
            prefill: "Forecast my metrics for the next 7 days"
        ),
        QuickActionItem(
            icon: "fork.knife",
            color: .biteRed,
            title: "Log food",
            subtitle: "Track your daily intake",
            prefill: "Help me log a meal"
        ),
        QuickActionItem(
            icon: "testtube.2",
            color: .biteHydration,
            title: "Analyze labs",
            subtitle: "Review bloodwork",
            prefill: "Analyze my latest labs"
        ),
        QuickActionItem(
            icon: "heart.fill",
            color: .biteRingNutrition,
            title: "Symptom check",
            subtitle: "Describe how you feel",
            prefill: "I'd like to do a symptom check"
        ),
        QuickActionItem(
            icon: "figure.run",
            color: .biteCarbs,
            title: "Training plan",
            subtitle: "Personalize for goals",
            prefill: "Build me a training plan"
        ),
        QuickActionItem(
            icon: "pin.fill",
            color: .biteFat,
            title: "Goal setting",
            subtitle: "Define a target",
            prefill: "Help me set a new goal"
        )
    ]

    private struct QuickActionItem {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let prefill: String
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
                .focused($inputFocused)
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
