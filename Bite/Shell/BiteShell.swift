import SwiftUI

struct BiteShell: View {
    @Binding var userProfile: UserProfile
    @Binding var pendingDeepLink: BiteDeepLink?
    @State private var router = BiteRouter()
    @State private var keyboard = KeyboardObserver()
    @Namespace private var morphNS

    init(userProfile: Binding<UserProfile>, pendingDeepLink: Binding<BiteDeepLink?> = .constant(nil)) {
        self._userProfile = userProfile
        self._pendingDeepLink = pendingDeepLink
    }

    private var overlayActive: Bool {
        router.route != .home || router.modalSheet != nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Home layer — always rendered, pushed back when an overlay is on top.
                homeLayer
                    .scaleEffect(overlayActive ? 0.94 : 1, anchor: UnitPoint(x: 0.5, y: 0.6))
                    .blur(radius: overlayActive ? 8 : 0)
                    .brightness(overlayActive ? -0.04 : 0)
                    .animation(BiteMotion.homePushBack, value: overlayActive)
                    .allowsHitTesting(!overlayActive)
                    .zIndex(0)

                // Chat overlay — fades in/out so the matchedGeometryEffect
                // between AskBitePill and CoachView's composer drives the
                // visible morph. (Sliding via offset(y:) breaks the shared
                // coordinate space matchedGeometryEffect needs.)
                CoachView(router: router, morphNS: morphNS, userProfile: $userProfile)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BiteGradientBackground(style: .coach))
                    .opacity(router.route == .chat ? 1 : 0)
                    .allowsHitTesting(router.route == .chat)
                    .animation(BiteMotion.chatMorph, value: router.route)
                    .zIndex(2)

                // Files now lives as a native sheet (see .sheet modifier
                // below). Removing the route-driven overlay so Apple Files-
                // style detents + drag-to-dismiss handle presentation.

                // V2 modal-sheet host — sits above the route layer, scrim handles
                // tap-to-dismiss; the home layer's scale/blur is driven by
                // overlayActive (which already accounts for modalSheet != nil).
                if router.modalSheet != nil {
                    modalSheetLayer
                        .zIndex(3.5)
                }

                // Drawer overlay (above everything else)
                DrawerView(router: router)
                    .zIndex(4)
            }
        }
        .sheet(isPresented: Binding(
            get: { router.plusSheetOpen },
            set: { if !$0 { router.closePlusSheet() } }
        )) {
            PlusSheet(router: router)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { router.filesSheetOpen },
            set: { if !$0 { router.closeFiles() } }
        )) {
            FilesScreen(router: router)
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .fullScreenCover(item: Binding(
            get: { router.activeWorkoutSession },
            set: { if $0 == nil { router.endWorkoutSession() } }
        )) { ctx in
            WorkoutSessionView(context: ctx) {
                router.endWorkoutSession()
            }
            .environment(router)
        }
        .environment(router)
        .environment(\.keyboard, keyboard)
        .onChange(of: pendingDeepLink) { _, link in
            handleDeepLink(link)
        }
        .onAppear {
            handleDeepLink(pendingDeepLink)
        }
    }

    private func handleDeepLink(_ link: BiteDeepLink?) {
        guard let link else { return }
        defer { pendingDeepLink = nil }
        switch link {
        case .today:     router.homeTab = .home
        case .journal:   router.homeTab = .journal
        case .fitness:   router.homeTab = .fitness
        case .biology:   router.homeTab = .biology
        case .hydration: router.openModal(.hydration)
        }
    }

    @ViewBuilder
    private var homeLayer: some View {
        ZStack {
            BiteGradientBackground(style: .today)

            // Tab content swap
            Group {
                switch router.homeTab {
                case .home:    TodayView(userProfile: $userProfile)
                case .journal: JournalView()
                case .fitness: FitnessView(router: router)
                case .biology: BiologyView(router: router)
                }
            }
            .transition(.opacity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !router.route.hidesAskPill && router.modalSheet == nil {
                floatingControls
            }
        }
    }

    @ViewBuilder
    private var floatingControls: some View {
        VStack(spacing: 12) {
            AskBitePill(router: router, morphNS: morphNS)
            if !keyboard.isVisible {
                HomeBottomTabPill(router: router, morphNS: morphNS)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, keyboard.isVisible ? 8 : BiteTheme.tabPillBottomInset)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: keyboard.isVisible)
    }

    @ViewBuilder
    private var modalSheetLayer: some View {
        ZStack(alignment: .bottom) {
            // Scrim — animates from clear to ~30% black so the sheet entrance
            // doesn't feel like a hard cut.
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture {
                    BiteHaptics.selection()
                    router.closeModal()
                }
                .transition(.opacity.animation(BiteMotion.scrimFade))

            modalSheetContent
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private var modalSheetContent: some View {
        if let sheet = router.modalSheet {
            switch sheet {
            case .hydration:
                HydrationSheet(router: router)
            case .caffeine:
                CaffeineSheet(router: router)
            case .activityStatus:
                ActivityStatusSheet(router: router)
            case .smartAlarm:
                SmartAlarmSheet(router: router)
            case .menstrualLog:
                MenstrualLogSheet(router: router)
            case .strengthExerciseLibrary:
                CustomExerciseLibraryView(router: router)
            }
        }
    }
}
