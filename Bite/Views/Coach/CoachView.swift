import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CoachView: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID
    @Binding var userProfile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\CoachThread.lastMessageAt, order: .reverse)])
    private var allThreads: [CoachThread]

    @State private var input: String = ""
    @State private var chat: CoachChatViewModel?
    @State private var inputFocused: Bool = false
    @State private var composerInputHeight: CGFloat = 22
    @State private var selectedAgentMode: AgentMode = .auto

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

    private var shouldShowHero: Bool {
        guard let chat else { return true }
        let hasPersistedMessages = !(chat.thread?.messages.isEmpty ?? true)
        let hasLiveWork = !chat.streamingText.isEmpty || !chat.thinkingSteps.isEmpty || chat.isStreaming
        return !hasPersistedMessages && !hasLiveWork && chat.mode == .idle
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
            ensureChat()
            if let requested = router.requestedCoachThread {
                chat?.openThread(requested)
            }
            if router.route == .chat {
                focusComposerAfterOpen()
            }
        }
        .onChange(of: router.requestedCoachThread?.id) { _, _ in
            ensureChat()
            if let requested = router.requestedCoachThread {
                input = ""
                chat?.openThread(requested)
            }
        }
        .onChange(of: router.newChatRequestID) { _, _ in
            ensureChat()
            input = ""
            chat?.resetForNewThread()
            focusComposerAfterOpen()
        }
        .onChange(of: router.route) { _, route in
            if route == .chat {
                focusComposerAfterOpen()
            } else {
                inputFocused = false
            }
        }
        .onChange(of: router.prefilledChatPrompt) { _, value in
            if let value, !value.isEmpty { input = value }
        }
        .onChange(of: router.autoSendChatMessage) { _, value in
            if let value, !value.isEmpty {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    chat?.send(value)
                    router.autoSendChatMessage = nil
                }
            }
        }
    }

    private var header: some View {
        BiteTopBar(onBack: nil) {
            HStack {
                Button { router.toggleDrawer() } label: {
                    chromeButtonLabel {
                        TwoLineHamburgerIcon()
                            .foregroundStyle(.biteInk)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Threads")
                // Badge sits in a separate overlay anchored to the button's
                // outer frame so it never affects the inner icon's centering
                // (otherwise the badge layer perturbs the HStack alignment
                // and the drawer button drifts off-axis from the close X).
                .overlay(alignment: .topTrailing) {
                    if threadCount > 0 {
                        Text("\(threadCount)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.biteRed, in: Capsule())
                            .offset(x: 4, y: -4)
                            .allowsHitTesting(false)
                    }
                }

                Spacer()

                Button { router.closeOverlay() } label: {
                    chromeButtonLabel(systemImage: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    /// Identical 56×56 Liquid-Glass circle for both the drawer button and
    /// the close button. Keeping the structure identical guarantees the two
    /// buttons sit at the exact same vertical position inside the BiteTopBar
    /// row, mirrored across the centerline.
    private func chromeButtonLabel(systemImage: String) -> some View {
        chromeButtonLabel {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.biteInk)
        }
    }

    private func chromeButtonLabel<Icon: View>(@ViewBuilder icon: () -> Icon) -> some View {
        icon()
            .frame(
                width: BiteTheme.topBarButtonSize,
                height: BiteTheme.topBarButtonSize
            )
            .glassEffect(.regular.tint(.white.opacity(0.4)).interactive(), in: .circle)
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    @ViewBuilder
    private var transcriptScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if shouldShowHero {
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
            agentCapabilityStrip
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
                if chat.isStreaming && (!chat.recentToolActivities.isEmpty || chat.activeToolName != nil) {
                    AgentActivityStrip(activities: chat.recentToolActivities)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if !chat.streamingText.isEmpty, chat.mode == .response {
                    AssistantText(text: chat.streamingText)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if !chat.researchCitations.isEmpty {
                    ResearchCitationStrip(citations: chat.researchCitations)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let error = chat.lastError, chat.mode == .error {
                    VStack(spacing: 10) {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.biteRed)
                            .multilineTextAlignment(.center)
                        if chat.canRetry {
                            Button {
                                BiteHaptics.impact(.light)
                                chat.retryLastSend()
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.biteRed)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                if let receipt = chat.lastInlineReceipt {
                    InlineReceiptChip(receipt: receipt) {
                        BiteHaptics.impact(.light)
                        router.recordToolReceipt(receipt)
                        router.revealLastReceipt()
                        chat.lastInlineReceipt = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(BiteMotion.bubbleRise, value: chat.streamingText)
            .animation(BiteMotion.bubbleRise, value: chat.thinkingSteps.count)
            .animation(BiteMotion.bubbleRise, value: chat.recentToolActivities)
            .animation(BiteMotion.bubbleRise, value: chat.lastInlineReceipt?.timestamp)
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

    private var agentCapabilityStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                AgentCapabilityChip(systemImage: "waveform.path.ecg", title: "Health data")
                AgentCapabilityChip(systemImage: "doc.text.magnifyingglass", title: "Files")
                AgentCapabilityChip(systemImage: "book.closed.fill", title: "Research")
                AgentCapabilityChip(systemImage: "brain.head.profile", title: "Memory")
            }
            .padding(.horizontal, 24)
        }
        .scrollDisabled(true)
        .padding(.top, 4)
    }

    private var quickActions: some View {
        Group {
            if shouldShowHero {
                GlassEffectContainer(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
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
                }
                .padding(.bottom, 8)
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
        let expanded = composerExpanded
        let cornerRadius: CGFloat = expanded ? 25 : BiteTheme.pillCornerRadius

        return VStack(alignment: .leading, spacing: expanded ? 8 : 0) {
            if expanded {
                agentModeStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(alignment: .bottom, spacing: 7) {
                Button {
                    router.openPlusSheet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.biteInk)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.95), in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(.plain)

                composerTextInput
                    .padding(.vertical, 7)
                    .frame(minHeight: 36)

                Button {} label: {
                    Image(systemName: "mic")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.biteInkMuted)
                        .frame(width: 30, height: 36)
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
                            .background(sendDisabled ? Color.biteInk.opacity(0.24) : Color.biteInk, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(sendDisabled)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 7)
        .padding(.vertical, expanded ? 8 : 7)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color.biteRedTint.opacity(0.54),
                            Color.white.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.white.opacity(0.86), lineWidth: 1))
        .shadow(color: Color.biteRed.opacity(0.12), radius: 26, x: 0, y: 9)
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 5)
        .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .matchedGeometryEffect(id: "composer", in: morphNS)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .animation(BiteMotion.chatMorph, value: expanded)
        .animation(BiteMotion.chatMorph, value: composerInputHeight)
    }

    private var composerTextInput: some View {
        ZStack(alignment: .topLeading) {
            if input.isEmpty {
                Text("Ask Bite anything")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
            ExpandingCoachTextView(
                text: $input,
                isFocused: $inputFocused,
                dynamicHeight: $composerInputHeight,
                onSubmit: submit
            )
            .frame(height: composerInputHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composerExpanded: Bool {
        inputFocused || !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat?.isStreaming == true
    }

    private var sendDisabled: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var agentModeStrip: some View {
        HStack(spacing: 6) {
            ForEach(AgentMode.allCases, id: \.self) { mode in
                Button {
                    BiteHaptics.selection()
                    selectedAgentMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10.5, weight: .bold))
                        Text(mode.title)
                            .font(.system(size: 11.5, weight: .heavy))
                    }
                    .foregroundStyle(selectedAgentMode == mode ? .white : .biteInkMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(selectedAgentMode == mode ? Color.biteInk : Color.white.opacity(0.62), in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(selectedAgentMode == mode ? 0 : 0.05), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ensureChat() {
        guard chat == nil else { return }
        let api = BiteAPIClient(auth: AuthService.shared)
        let remote = RemoteAIService(api: api)
        chat = CoachChatViewModel(modelContext: modelContext, remote: remote, auth: AuthService.shared)
    }

    private func focusComposerAfterOpen() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            inputFocused = true
        }
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chat else { return }
        input = ""
        composerInputHeight = 22
        chat.send(text, contextHint: selectedAgentMode.contextHint)
    }
}

private enum AgentMode: CaseIterable {
    case auto, research, files, health

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .research: return "Research"
        case .files: return "Files"
        case .health: return "Health"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .research: return "book.closed.fill"
        case .files: return "doc.text.magnifyingglass"
        case .health: return "waveform.path.ecg"
        }
    }

    var contextHint: String? {
        switch self {
        case .auto:
            return nil
        case .research:
            return "Agent routing hint: prioritize the research_science tool for scientific claims, mechanisms, protocols, and source-backed recommendations. Return concise clickable citations."
        case .files:
            return "Agent routing hint: prioritize uploaded files, health records, and document context before giving advice. If no relevant file is available, say what would help."
        case .health:
            return "Agent routing hint: prioritize the user's health snapshot, logged food, sleep, recovery, activity status, and Apple Health-derived metrics when reasoning."
        }
    }
}

private struct AgentCapabilityChip: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11.5, weight: .heavy))
        }
        .foregroundStyle(.biteInkMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.58), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.72), lineWidth: 1))
    }
}

private struct AgentActivityStrip: View {
    let activities: [CoachChatViewModel.ToolActivity]

    var body: some View {
        HStack(spacing: 8) {
            BiteOrbImage(size: 26, mood: .think, state: hasRunningTool ? .thinking : .idle, showHalo: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(hasRunningTool ? "Bite is working" : "Agent actions")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.biteInk)
                HStack(spacing: 6) {
                    ForEach(activities.prefix(3)) { activity in
                        AgentActivityPill(activity: activity)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.82), lineWidth: 1))
    }

    private var hasRunningTool: Bool {
        activities.contains { $0.status == .running }
    }
}

private struct AgentActivityPill: View {
    let activity: CoachChatViewModel.ToolActivity

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(activity.label)
                .font(.system(size: 10.5, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: Capsule())
    }

    private var tint: Color {
        switch activity.status {
        case .running: return .biteCarbs
        case .done: return .biteRingRecovery
        case .failed: return .biteRed
        }
    }

    private var icon: String {
        switch activity.status {
        case .running: return "arrow.triangle.2.circlepath"
        case .done: return "checkmark"
        case .failed: return "exclamationmark"
        }
    }
}

private struct TwoLineHamburgerIcon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .frame(width: 20, height: 2)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .frame(width: 10, height: 2)
        }
        .frame(width: 20, height: 14, alignment: .leading)
    }
}

#if canImport(UIKit)
private struct ExpandingCoachTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var dynamicHeight: CGFloat
    var onSubmit: () -> Void

    private let minVisibleLines: CGFloat = 1
    private let maxVisibleLines: CGFloat = 5

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero, textContainer: nil)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor(Color.biteInk)
        textView.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.returnKeyType = .send
        textView.enablesReturnKeyAutomatically = true
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = false
        textView.keyboardDismissMode = .none
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.updateHeight(textView, force: true)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        context.coordinator.dynamicHeight = $dynamicHeight
        context.coordinator.onSubmit = onSubmit

        if uiView.text != text {
            uiView.text = text
        }
        if isFocused, !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused, uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }
        context.coordinator.updateHeight(uiView, force: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            dynamicHeight: $dynamicHeight,
            onSubmit: onSubmit,
            minVisibleLines: minVisibleLines,
            maxVisibleLines: maxVisibleLines
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var dynamicHeight: Binding<CGFloat>
        var onSubmit: () -> Void
        private let minVisibleLines: CGFloat
        private let maxVisibleLines: CGFloat

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            dynamicHeight: Binding<CGFloat>,
            onSubmit: @escaping () -> Void,
            minVisibleLines: CGFloat,
            maxVisibleLines: CGFloat
        ) {
            self.text = text
            self.isFocused = isFocused
            self.dynamicHeight = dynamicHeight
            self.onSubmit = onSubmit
            self.minVisibleLines = minVisibleLines
            self.maxVisibleLines = maxVisibleLines
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused.wrappedValue = false
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text ?? ""
            updateHeight(textView, force: true)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            if replacement == "\n" {
                onSubmit()
                return false
            }
            return true
        }

        func updateHeight(_ textView: UITextView, force: Bool) {
            let lineHeight = textView.font?.lineHeight ?? 18
            let minHeight = ceil(lineHeight * minVisibleLines)
            let maxHeight = ceil(lineHeight * maxVisibleLines)
            let width = max(textView.bounds.width, 1)
            let measured = ceil(textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            let nextHeight = min(max(measured, minHeight), maxHeight)
            let shouldScroll = measured > maxHeight + 1
            if textView.isScrollEnabled != shouldScroll {
                textView.isScrollEnabled = shouldScroll
            }
            guard force || abs(dynamicHeight.wrappedValue - nextHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                if abs(self.dynamicHeight.wrappedValue - nextHeight) > 0.5 {
                    self.dynamicHeight.wrappedValue = nextHeight
                }
            }
        }
    }
}
#endif
