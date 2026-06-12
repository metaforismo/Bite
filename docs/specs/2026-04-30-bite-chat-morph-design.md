# Bite Phase D — Chat morph

**Date:** 2026-04-30
**Scope:** Simplify the home AskBitePill, replace the slide-in route to Coach
with a true geometry morph from the pill to the full-screen composer,
redesign the Coach idle screen to match the user's reference (orb hero +
dynamic greeting + horizontal quick-action card row), and migrate the Coach
header to the project's `BiteTopBar` primitive.
**Out of scope:** Drawer threads UI internals, new orb animations, dismiss
gestures, additional quick actions beyond the six listed below, changes to
`CoachChatViewModel` (streaming, tool use, transcript rendering).

## Goal

Make the act of opening the chat feel like the pill itself becoming the chat,
not like a separate sheet sliding over the home screen. The user's reference
("the pill rapidly expands its width and height, morphing into the full-screen
chat sheet") is a direct geometry transition, not a layered presentation.

The redesign also simplifies the home pill — it stops doubling as a textfield —
and refreshes the Coach idle screen with a personal greeting and a small set
of quick-start cards instead of an undifferentiated chip carousel.

## Background

### Today's behavior

`AskBitePill` is a two-state component. Tap collapsed → it expands inline,
showing a horizontal chip carousel and a textfield with `+` and send buttons;
the user types in place; submitting routes to `CoachView` via
`router.openChat(prefill:)`.

`BiteShell` then animates `CoachView` in with `offset(y:)`:

```swift
CoachView(router: router, morphNS: morphNS)
    .offset(y: router.route == .chat ? 0 : geometry.size.height)
    .animation(BiteMotion.routeSheet, value: router.route)
```

`AskBitePill` already declares `matchedGeometryEffect(id: "composer", in: morphNS)`
on both its collapsed and expanded states, and `CoachView`'s composer
declares the matching effect — so the geometry-bridge primitives are in
place but the offset transition in `BiteShell` overrides them, breaking the
coordinate space. Today the morph is wired but never visually fires.

### Today's Coach idle screen

`CoachView` renders, when `chat?.mode == .idle`:

- `BiteOrbImage(size: 130, ...)` centered
- Date stamp
- Static title: "What should we look at?"
- Horizontal `ScrollView` with 7 `QuickActionChip` rows (icon tile + title + sub)
- Composer at bottom

### What changes in Phase D

1. The pill drops its expanded state. Tap → open chat directly.
2. `BiteShell` swaps the `offset(y:)` slide for an `opacity` fade so the
   `matchedGeometryEffect` between pill and composer drives the visible motion.
3. `CoachView` idle gets a new layout: dynamic greeting using the user's
   first name, two large cards visible at rest, the rest reachable via
   horizontal scroll. The chip carousel is gone.
4. `CoachView` header migrates to `BiteTopBar` for parity with onboarding
   and gets a thread-count badge on the drawer button.

## Non-goals

- Modifying the chat transcript, streaming behavior, or tool-use flow.
- Drawer threads UI (badge value comes from a count, but the drawer itself
  is unchanged).
- Adding swipe-down-to-dismiss or any gesture beyond the existing close
  button.
- Replacing the orb with a Rive animation. `BiteOrbImage` stays.
- Redesigning the non-idle states (`thinking`, `listening`, `response`,
  `error`). Those keep their current rendering.

## Architecture

### New files

- `Bite/Views/Coach/QuickActionCard.swift` — large card (180×100pt) used in
  the new horizontal row. Replaces the `QuickActionChip` private struct
  inside `CoachView.swift`.

### Removed code

- `AskBitePill`'s entire `expanded` branch (~120 lines): chip carousel,
  textfield, `+`/send buttons, focus state, query state.
- `QuickActionChip` private struct in `CoachView.swift`.

### Edited files

- `Bite/Views/Today/AskBitePill.swift` — collapsed-only Button.
- `Bite/Views/Coach/CoachView.swift` — header migrates to `BiteTopBar`;
  idle hero gets dynamic greeting + new quick-action card row.
- `Bite/Shell/BiteShell.swift` — replaces `.offset(y:)` route animation
  with `.opacity` so `matchedGeometryEffect` drives the morph.
- `Bite/Design/BiteMotion.swift` — adds `chatMorph` spring
  (`response: 0.45, dampingFraction: 0.82, blendDuration: 0`).

## Components

### `AskBitePill` (rewritten)

```swift
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

No more `@State query`, `@State isExpanded`, `@FocusState focused`, or
inline carousel. The pill is purely a portal into the chat.

### `CoachView` idle layout

The body remains a `VStack(spacing: 0) { header; transcriptScroll; quickActions; composer }`.
The changes are:

**Header** (`var header`): rewritten on top of `BiteTopBar`.

```swift
private var header: some View {
    BiteTopBar(
        onBack: nil  // no back; close goes via the trailing X
    ) {
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
                    .frame(width: BiteTheme.topBarButtonSize,
                           height: BiteTheme.topBarButtonSize)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}
```

`drawerButtonLabel` is a 56×56 ultra-thin-material circle with the
`line.3.horizontal` icon and a small red badge in the top-right corner
showing the thread count when > 0:

```swift
private var drawerButtonLabel: some View {
    Image(systemName: "line.3.horizontal")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.biteInk)
        .frame(width: BiteTheme.topBarButtonSize,
               height: BiteTheme.topBarButtonSize)
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

private var threadCount: Int {
    chat?.recentThreadsCount ?? 0  // existing or stub on CoachChatViewModel
}
```

If `recentThreadsCount` doesn't exist on the view model, the implementation
adds a one-line computed property over `modelContext` (counts `CoachThread`
rows). Falls back to `0` if the count can't be determined; in that case the
badge is hidden, not stuck at `1`.

**Hero** (`var heroOrb`): unchanged orb but the title becomes dynamic.

```swift
private var greeting: String {
    let trimmed = userProfile.name.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "What's up?" : "What's up, \(trimmed)?"
}
```

`userProfile` reaches `CoachView` via a new `@Binding var userProfile: UserProfile`
parameter (added at the call site in `BiteShell.swift`). If wiring the binding
proves invasive, the implementation falls back to reading `StorageService.shared.loadProfile()?.name`
inside the view — acceptable because it's a read-only display string and the
profile is already cached in storage.

**Quick action row** (`var quickActions`): replaces the chip carousel.

```swift
private var quickActions: some View {
    Group {
        if chat?.mode == .idle || chat == nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickActionItems) { item in
                        QuickActionCard(
                            systemImage: item.icon,
                            iconColor: item.color,
                            title: item.title,
                            subtitle: item.subtitle
                        ) {
                            input = item.prefill
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
    }
}
```

`quickActionItems` is a static `[QuickAction]` of 6 entries (Predictive
modeling, Log food, Analyze labs, Symptom check, Training plan, Goal
setting). Tapping a card pre-fills the composer's text input via `input =
item.prefill` and brings up the keyboard via the existing
`@FocusState`-based focus on the composer (`@FocusState` is added if not
already present — the implementation step verifies and adds it if needed).
The user can edit before sending. The card never auto-submits.

### `QuickActionCard`

```swift
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
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
```

Card width 200pt × height 76pt (slightly more compact than the spec's
180×100 to fit the typography cleanly). Two cards visible at rest on a
standard iPhone width, with the third peeking on the right edge to signal
scrollability.

### Animation: `BiteShell` route transition

```swift
// before
CoachView(...)
    .offset(y: router.route == .chat ? 0 : geometry.size.height)
    .animation(BiteMotion.routeSheet, value: router.route)

// after
CoachView(...)
    .opacity(router.route == .chat ? 1 : 0)
    .allowsHitTesting(router.route == .chat)
    .animation(BiteMotion.chatMorph, value: router.route)
```

`FilesScreen` keeps its `offset(y:)` slide — Phase D doesn't touch the
files route; only the chat morph is in scope.

### `BiteMotion.chatMorph`

```swift
static let chatMorph = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)
```

Response 0.45 is long enough that the composer's expansion from a 50pt-tall
pill to a full-width chat composer reads smoothly; damping 0.82 prevents
the perceived "bounce" that 0.7 would introduce on an element this
prominent.

## Layout rules

- Coach idle hero starts at `y >= 150pt` (the same reserved-zone rule the
  onboarding follows). `BiteTopBar` already enforces the 56pt + safe-area
  + 12pt at the top; the existing `BiteTheme.topPadding = 56` plus the new
  top-bar safe-area padding push the hero into the right zone.
- Quick action cards live in the lower third of the screen above the
  composer. The composer remains pinned to bottom with the existing
  `BiteTheme.composerHeight` and `padding(.bottom, 20)`.
- Touch targets: every interactive element on the new screens is ≥ 44×44pt
  (drawer button 56, close 56, card 200×76, composer buttons 36×36 — under
  44, but they're inside a 50pt-tall composer row, so the effective tap
  area passes through `.contentShape(Capsule())` and remains comfortable).

## Validation

### Build
- `mcp__xcodebuildmcp__build_sim` clean.

### Visual smoke (simulator iPhone 17)
1. **Home pill** — orb mini PNG + "Ask Bite anything" placeholder; no
   inline expansion when tapped.
2. **Tap pill → chat morph** — three sequential screenshots during the
   ~0.45s spring window. Verify: composer stays anchored at bottom; orb
   hero, greeting, cards fade in coherently; no mid-transition jump.
3. **Coach idle** — orb centered; date stamp; "What's up, Test?" greeting;
   2 cards visible (Predictive modeling + Log food); third card peeks on
   the right edge.
4. **Horizontal scroll** — swipe left reveals Analyze labs, Symptom
   check, Training plan, Goal setting.
5. **Tap card** — composer input pre-fills; keyboard rises; focus on
   textfield. No auto-send.
6. **Tap close (X)** — reverse morph; composer collapses back into pill.
7. **Drawer badge** — visible when `threadCount > 0`; hidden when 0.

### Edge cases
- Tap pill while a thread is mid-stream (`mode != .idle`) → opens directly
  into the active thread, not the idle hero.
- Empty `userProfile.name` → greeting reads "What's up?" (no comma).
- Keyboard open on composer → composer rises above keyboard via the
  existing `KeyboardObserver`.
- Plus sheet open (`router.modalSheet != nil`) → pill hidden via the
  existing `hidesAskPill` check; no morph fires.

### Tests
No new unit tests. View-layer change with no business logic delta.
Existing tests must continue to pass.

## Risks & mitigations

- **`matchedGeometryEffect` flicker if both pill and composer are
  simultaneously rendered** — `BiteShell` already conditionally renders
  the pill via `.safeAreaInset` only when `!router.route.hidesAskPill`,
  and the composer is always inside `CoachView`. During the morph SwiftUI
  needs both visible at once for one frame, which is exactly what
  `matchedGeometryEffect` expects. Verify in the visual smoke.
- **`.opacity` transition revealing the chat behind the pill prematurely**
  — mitigation: `BiteGradientBackground` is part of `CoachView`'s
  `.background(...)` modifier, so it fades together with the foreground
  content. No two-stage reveal.
- **Thread count source unknown** — mitigation: ship with `threadCount = 0`
  fallback (badge hidden) if `CoachChatViewModel` doesn't expose the
  count. Don't let badge wiring block the morph work.
- **`@Binding var userProfile`** — adding a binding to `CoachView` ripples
  through `BiteShell` and any callers. Mitigation: if the diff balloons,
  fall back to `StorageService.shared.loadProfile()?.name` for the
  greeting only.

## Implementation order

1. Add `BiteMotion.chatMorph`.
2. Build `QuickActionCard.swift` with the 6 quick-action data items.
3. Rewrite `AskBitePill.swift` (collapsed-only).
4. Rewrite `CoachView` header on `BiteTopBar`; replace chip carousel with
   `QuickActionCard` row; switch greeting to dynamic.
5. Update `BiteShell` to use `.opacity` for the chat route.
6. Build + visual smoke + close-morph verification.
7. Commit on `design/phase-d-chat-morph` branch; open PR.
