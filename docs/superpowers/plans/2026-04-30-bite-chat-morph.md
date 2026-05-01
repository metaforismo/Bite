# Bite Phase D — Chat Morph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home pill's two-state expansion with a direct geometry morph into the full-screen Coach composer; redesign the Coach idle screen with a dynamic greeting and large quick-action cards; migrate the Coach header to `BiteTopBar` with a thread-count badge.

**Architecture:** All work is SwiftUI view-layer. The pill becomes a single `Button` that triggers `router.openChat(prefill: nil)`. `BiteShell` swaps its `offset(y:)` route animation for `.opacity`, letting the existing `matchedGeometryEffect(id: "composer")` between pill and Coach composer drive the visible motion. The Coach idle hero gains a dynamic greeting bound to `userProfile.name` and a horizontal `ScrollView` of `QuickActionCard` views replaces the previous chip carousel.

**Tech Stack:** SwiftUI (iOS 18+), SwiftData (`@Query` for `CoachThread` count), `matchedGeometryEffect`, `BiteMotion` spring animations, `xcodebuildmcp` for sim build/run/screenshot.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Bite/Design/BiteMotion.swift` | edit | Add `chatMorph` spring constant |
| `Bite/Views/Coach/QuickActionCard.swift` | new | Reusable 200×76 card for the quick-action row |
| `Bite/Views/Today/AskBitePill.swift` | rewrite | Collapsed-only `Button` that opens chat |
| `Bite/Views/Coach/CoachView.swift` | rewrite (header + idle) | `BiteTopBar` header, dynamic greeting, `QuickActionCard` row, badge |
| `Bite/Shell/BiteShell.swift` | edit | `.opacity` instead of `.offset(y:)` for chat route; pass `userProfile` binding to `CoachView` |
| `Bite/Shell/BiteRoute.swift` | edit | `openChat`/`closeOverlay` use `BiteMotion.chatMorph` instead of `routeSheet` |

---

## Task 1: Add `chatMorph` animation constant

**Files:**
- Modify: `Bite/Design/BiteMotion.swift:6-31`

- [ ] **Step 1: Open `BiteMotion.swift` and locate the `BiteMotion` enum**

Existing constants live around lines 7-30. Add the new one alongside the other spring constants.

- [ ] **Step 2: Add `chatMorph` spring**

Modify `Bite/Design/BiteMotion.swift`. After the existing `static let progressBar = ...` line (around line 30), add:

```swift
    /// Chat morph timing — used by `BiteShell` when transitioning to/from
    /// the chat route. Response 0.45s lets the composer's geometry expand
    /// from the home pill (~50pt tall) to the full-width chat composer
    /// readably; damping 0.82 prevents the perceived bounce that 0.7
    /// would introduce on an element this prominent.
    static let chatMorph      = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)
```

- [ ] **Step 3: Verify it compiles**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Bite/Design/BiteMotion.swift
git commit -m "feat(motion): add chatMorph spring for pill→composer transition"
```

---

## Task 2: Build `QuickActionCard` component

**Files:**
- Create: `Bite/Views/Coach/QuickActionCard.swift`

- [ ] **Step 1: Create the new file**

Create `Bite/Views/Coach/QuickActionCard.swift` with this exact content:

```swift
import SwiftUI

/// Large card used in the Coach idle screen's quick-action row. Pre-fills
/// the composer with a starter prompt; never auto-submits — the user can
/// edit the text before sending.
///
/// Sized so that two cards fit on a standard iPhone width with a third
/// card peeking on the right edge to signal scrollability.
struct QuickActionCard: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: 200, height: 76)
            .background(
                Color.white.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .coach)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionCard(
                    systemImage: "chart.line.uptrend.xyaxis",
                    iconColor: .biteRingRecovery,
                    title: "Predictive modeling",
                    subtitle: "Forecast your metrics"
                ) {}
                QuickActionCard(
                    systemImage: "fork.knife",
                    iconColor: .biteRed,
                    title: "Log food",
                    subtitle: "Track your daily intake"
                ) {}
                QuickActionCard(
                    systemImage: "testtube.2",
                    iconColor: .biteHydration,
                    title: "Analyze labs",
                    subtitle: "Review bloodwork"
                ) {}
            }
            .padding(.horizontal, 16)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build succeeds. Xcode auto-discovers the file because the project uses `PBXFileSystemSynchronizedRootGroup`.

- [ ] **Step 3: Commit**

```bash
git add Bite/Views/Coach/QuickActionCard.swift
git commit -m "feat(coach): add QuickActionCard for chat idle quick-actions"
```

---

## Task 3: Simplify `AskBitePill` to collapsed-only

**Files:**
- Rewrite: `Bite/Views/Today/AskBitePill.swift`

- [ ] **Step 1: Replace the entire file content**

Rewrite `Bite/Views/Today/AskBitePill.swift` with:

```swift
import SwiftUI

/// Floating pill on Today. Shows a micro orb + "Ask Bite anything"
/// placeholder. Tap → opens `CoachView` directly via the chat route.
///
/// Pairs with `CoachView`'s composer through `matchedGeometryEffect(id:
/// "composer", in: morphNS)` so SwiftUI animates a single element morph
/// from this pill into the full-width Coach composer when the user taps.
struct AskBitePill: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID

    var body: some View {
        Button {
            BiteHaptics.impact(.light)
            router.openChat(prefill: nil)
        } label: {
            HStack(spacing: 10) {
                BiteOrbImage(size: 24, mood: .neutral, state: .idle, showHalo: false)
                Text("Ask Bite anything")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .background(Color.white.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 6)
        .glassEffect(in: .capsule)
        .matchedGeometryEffect(id: "composer", in: morphNS)
    }
}
```

This deletes ~120 lines: the `expanded` branch, chip carousel, inline textfield, `+`/send buttons, `MicroOrb` private struct (already replaced by `BiteOrbImage` in Phase 1), `submitTyped()`, `submit(prefill:)`, `collapse()`, `@State query`, `@State isExpanded`, `@FocusState focused`.

- [ ] **Step 2: Build to verify**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Bite/Views/Today/AskBitePill.swift
git commit -m "refactor(today): simplify AskBitePill to collapsed-only Button"
```

---

## Task 4: Update `BiteRouter` to use `chatMorph` for chat route

**Files:**
- Modify: `Bite/Shell/BiteRoute.swift:65-83`

- [ ] **Step 1: Change `openChat` animation**

In `Bite/Shell/BiteRoute.swift`, update the `openChat` method:

```swift
    func openChat(prefill: String? = nil, thenPlus: Bool = false) {
        prefilledChatPrompt = prefill
        withAnimation(BiteMotion.chatMorph) { route = .chat }
        if thenPlus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(BiteMotion.plusSheet) { plusSheetOpen = true }
            }
        }
    }
```

- [ ] **Step 2: Change `closeOverlay` animation when leaving chat**

Update `closeOverlay` to use `chatMorph` only when the current route is `.chat` so the files route keeps its slide:

```swift
    func closeOverlay() {
        let animation: Animation = (route == .chat) ? BiteMotion.chatMorph : BiteMotion.routeSheet
        withAnimation(animation) { route = .home }
    }
```

- [ ] **Step 3: Build to verify**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Bite/Shell/BiteRoute.swift
git commit -m "feat(router): use chatMorph spring for chat route transitions"
```

---

## Task 5: Update `BiteShell` to fade chat instead of sliding

**Files:**
- Modify: `Bite/Shell/BiteShell.swift:31-37` (CoachView overlay), `Bite/Shell/BiteShell.swift:107` (TodayView call site)

- [ ] **Step 1: Read the existing CoachView overlay block**

Read `Bite/Shell/BiteShell.swift` lines 31-37. The current code is:

```swift
                // Chat overlay
                CoachView(router: router, morphNS: morphNS)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BiteGradientBackground(style: .coach))
                    .offset(y: router.route == .chat ? 0 : geometry.size.height)
                    .animation(BiteMotion.routeSheet, value: router.route)
                    .zIndex(2)
```

- [ ] **Step 2: Replace with opacity-driven version**

Replace those lines with:

```swift
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
```

- [ ] **Step 3: Build to verify**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build fails — `CoachView` does not yet take a `userProfile` binding. Task 6 fixes this.

- [ ] **Step 4: Do not commit yet**

Leave the change uncommitted. Task 6 lands together with this in one commit because the API change cuts across both files.

---

## Task 6: Refactor `CoachView` — header, greeting, quick action cards

**Files:**
- Rewrite header + idle hero + quick actions in: `Bite/Views/Coach/CoachView.swift`
- Add binding: `Bite/Views/Coach/CoachView.swift` (top of struct)

- [ ] **Step 1: Add `userProfile` binding and `threadCount` query**

At the top of `CoachView` struct (around line 4), add:

```swift
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
```

Note: `@Query` needs `import SwiftData` if not already present at the top of the file. Verify the import is there; if not, add it.

- [ ] **Step 2: Add a computed property for thread count**

Below the existing computed `orbState` and `orbMood` (around line 31), add:

```swift
    private var threadCount: Int {
        allThreads.count
    }

    private var greeting: String {
        let trimmed = userProfile.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "What's up?" : "What's up, \(trimmed)?"
    }
```

- [ ] **Step 3: Replace the `header` computed property**

Find the existing `private var header: some View { ... }` (lines ~55-86) and replace with:

```swift
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
                        .background(.ultraThinMaterial, in: Circle())
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
            .background(.ultraThinMaterial, in: Circle())
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
```

This keeps the previous mini-orb-in-header logic OUT of the new header. The mini orb when `chat.mode != .idle` is no longer needed in the header because the new design's hero is always present in idle, and during streaming the transcript fills the screen anyway.

- [ ] **Step 4: Update the body to remove top padding override**

Find the body's `.padding(.top, BiteTheme.topPadding)` (line ~40) and remove it. `BiteTopBar` now handles the safe-area padding internally:

```swift
    var body: some View {
        VStack(spacing: 0) {
            header
            transcriptScroll
            quickActions
            composer
        }
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
```

- [ ] **Step 5: Replace the `heroOrb` computed property**

Find `private var heroOrb: some View { ... }` (lines ~113-129) and replace with:

```swift
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
```

- [ ] **Step 6: Replace the `quickActions` computed property**

Find `private var quickActions: some View { ... }` (lines ~174-207) and replace with:

```swift
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
```

- [ ] **Step 7: Wire `inputFocused` to the existing TextField**

Find the existing composer's `TextField("Ask Bite anything", text: $input)` (around line 223) and add the focus binding:

```swift
            TextField("Ask Bite anything", text: $input)
                .font(.system(size: 15))
                .foregroundStyle(.biteInk)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(submit)
```

- [ ] **Step 8: Delete the old `QuickActionChip` private struct**

Find `struct QuickActionChip: View { ... }` (around line 277 onwards) and delete the entire struct. It's no longer used.

- [ ] **Step 9: Update `shouldShowMiniOrbInHeader`**

The new header doesn't need this logic since the hero is the only orb. Find and delete the `shouldShowMiniOrbInHeader` computed property.

- [ ] **Step 10: Update preview at the bottom of file**

If there's a `#Preview` at the bottom, update it to include the new binding. If the file uses `BiteRouter` directly in preview, change it to:

```swift
#Preview {
    @Previewable @State var profile = UserProfile.empty
    CoachView(
        router: BiteRouter(),
        morphNS: Namespace().wrappedValue,
        userProfile: $profile
    )
}
```

If `UserProfile.empty` doesn't exist, replace with `UserProfile(name: "Test", calorieGoal: 2000, proteinGoal: 150, carbsGoal: 250, fatGoal: 65, hasCompletedOnboarding: true)` matching the model's required init parameters. Skip the preview update if any required parameter is unclear — previews aren't shipped, so a warning is acceptable; the implementer can refine after the main flow is verified.

- [ ] **Step 11: Build to verify**

Run: `mcp__xcodebuildmcp__build_sim`
Expected: build succeeds. If it fails on `UserProfile.empty` in the preview, edit the preview as described above.

- [ ] **Step 12: Commit Tasks 5 + 6 together**

The `userProfile` binding addition crosses both `BiteShell.swift` and `CoachView.swift`. Commit them together:

```bash
git add Bite/Shell/BiteShell.swift Bite/Views/Coach/CoachView.swift
git commit -m "feat(coach): redesign idle screen with greeting, cards, BiteTopBar

- Header migrates to BiteTopBar; drawer button gets thread-count badge.
- Idle hero gains a dynamic greeting (\"What's up, [name]?\") bound to
  userProfile.name with a graceful no-name fallback.
- Quick-action chip carousel replaced by horizontal QuickActionCard row.
- BiteShell fades CoachView via .opacity instead of .offset(y:) so the
  matchedGeometryEffect on the composer drives the morph from AskBitePill."
```

---

## Task 7: Visual smoke + behavior verification on simulator

**Files:** none (verification only)

- [ ] **Step 1: Build and run**

Run: `mcp__xcodebuildmcp__build_run_sim`
Expected: app launches without crash.

- [ ] **Step 2: Reset onboarding state for a clean run**

Run: `xcrun simctl uninstall C18D0DBC-7B11-494F-BA65-D28E545C4789 com.giannicolafrancesco.Bite`
Then re-run: `mcp__xcodebuildmcp__build_run_sim`

- [ ] **Step 3: Walk onboarding to set a name**

Tap "Let's go", skip permissions (4 skips), enter "Test" in the name field, complete onboarding. (Tapping "Skip" through every page should land on Today.)

If there's a way to bypass onboarding (e.g., a debug toggle), prefer that. Otherwise, complete it once and rely on the persisted profile for further runs.

- [ ] **Step 4: Capture Home pill screenshot**

Run: `mcp__xcodebuildmcp__screenshot`
Verify visually:
- Pill at bottom shows orb mini PNG + "Ask Bite anything" placeholder.
- No chip carousel above the pill.

- [ ] **Step 5: Tap pill, capture morph**

Run: `mcp__xcodebuildmcp__tap` with `label: "Ask Bite anything"`.
Take 2 screenshots in quick succession.
Verify:
- The composer stays anchored to the bottom.
- Orb hero, "Tue, …" date, "What's up, Test?" greeting, and 2 cards fade in.
- No mid-transition jump or flicker.

- [ ] **Step 6: Capture Coach idle final state**

Run: `mcp__xcodebuildmcp__screenshot`
Verify:
- Header: drawer button on the left (with badge if `threadCount > 0`), close button on the right. Both 56×56 in safe-area zone.
- Hero: orb 130pt, date "Tue, 30 Apr" (or current date), greeting "What's up, Test?".
- Two cards visible: Predictive modeling + Log food. Third card peeks on the right edge.
- Composer at bottom unchanged.

- [ ] **Step 7: Test horizontal scroll**

Run: `mcp__xcodebuildmcp__swipe` from a point on a card to the left to scroll the row.
Verify additional cards (Analyze labs, Symptom check, Training plan, Goal setting) are reachable.

- [ ] **Step 8: Test card tap pre-fills composer**

Run: `mcp__xcodebuildmcp__tap` with `label: "Predictive modeling"` (or coordinates if label isn't unique).
Take screenshot. Verify:
- Composer textfield shows "Forecast my metrics for the next 7 days".
- Keyboard is up.
- Send button is now red (active).

- [ ] **Step 9: Test reverse morph (close button)**

Run: `mcp__xcodebuildmcp__tap` with `label: "Close"`.
Take screenshot. Verify:
- Chat fades out.
- Composer collapses back into pill on the home screen.

- [ ] **Step 10: Edge case — empty name greeting**

This requires a fresh onboarding without filling the name. If labor-intensive, skip and rely on the code-level fallback (the `greeting` computed property has the empty-name branch).

- [ ] **Step 11: Mark Task 7 complete**

If all verifications pass, proceed to Task 8. If any step reveals a bug, fix it inline and re-run the affected step before continuing.

---

## Task 8: Push branch and open PR

**Files:** none (git only)

- [ ] **Step 1: Confirm we're on the feature branch**

Run: `git branch --show-current`
Expected output: `design/phase-d-chat-morph`

If not on this branch, the spec was committed elsewhere — abort and resolve.

- [ ] **Step 2: Show recent commits**

Run: `git log --oneline -10`
Expected: should show the spec commit, the motion commit, the QuickActionCard commit, the AskBitePill commit, the router commit, and the combined CoachView+BiteShell commit (5-6 commits since `main`).

- [ ] **Step 3: Push branch**

Run: `git push -u origin design/phase-d-chat-morph`

- [ ] **Step 4: Open PR via gh CLI**

Run:

```bash
gh pr create --title "Phase D — chat morph + Coach idle redesign" --body "$(cat <<'EOF'
## Summary
- Replaces the home pill's two-state expansion with a direct geometry morph into the full-screen Coach composer.
- Redesigns Coach idle: dynamic "What's up, [name]?" greeting, horizontal QuickActionCard row (6 starter prompts), BiteTopBar header with drawer thread-count badge.
- Swaps `BiteShell`'s chat-route `.offset(y:)` slide for `.opacity` so the existing `matchedGeometryEffect(id: "composer")` drives the morph.

## Spec
docs/superpowers/specs/2026-04-30-bite-chat-morph-design.md

## Test plan
- [x] Build clean on iOS Simulator
- [x] Tap pill on Home → morph plays without flicker; composer remains anchored
- [x] Coach idle shows orb, date, greeting with name, 2 cards visible + 3rd peeking
- [x] Horizontal scroll reveals all 6 cards
- [x] Tap card pre-fills composer + raises keyboard, no auto-send
- [x] Close (X) reverse morph collapses composer back into pill
- [x] Drawer button shows thread-count badge when > 0

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: Capture PR URL**

The `gh pr create` output prints the PR URL. Save it to share with the user.

- [ ] **Step 6: Final commit** (if any uncommitted polish)

If the visual smoke revealed minor polish (typo, padding tweak), commit those follow-up fixes before finalizing the PR. Each fix gets its own focused commit.

---

## Out of scope reminders

- Drawer threads UI internals (only the badge is in scope).
- Rive orb animation (Phase 2+).
- Swipe-down-to-dismiss gesture on chat.
- Adding more quick actions beyond the 6 listed.
- Changes to streaming/tool-use logic.

## Self-review notes

- Task 5 builds against an API that Task 6 introduces. The plan flags this and asks the implementer to commit them together (Step 12 of Task 6).
- `UserProfile.empty` is referenced in the preview update (Task 6 Step 10) with a graceful fallback if it doesn't exist; previews are not shipped.
- Thread count uses `@Query` over `CoachThread`. If `CoachThread` is not a SwiftData model class (`@Model`), this query will not compile — the implementer should verify by reading `Bite/Models/Coach/CoachThread.swift` first. Fallback: `chat?.thread.map { _ in 1 } ?? 0` (binary "is there an active thread?" badge).
- All animation constants used (`BiteMotion.chatMorph`) are defined in Task 1 before Task 4 references them.
