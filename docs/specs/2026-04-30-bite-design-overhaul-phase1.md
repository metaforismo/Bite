# Bite Design Overhaul — Phase 1

**Date:** 2026-04-30
**Scope:** Groups A (critical bugs) + B (orb asset swap) + C (top safe area + segmented progress bar)
**Out of scope (deferred):** Group D (home pill simplification + chat morph) and Group E (Rive animation, custom asset library) — separate specs.

## Goal

Replace the procedural SwiftUI orb with the new `biteorbs.png` mascot, fix the unreachable back button + cycle progress bar in onboarding, fix the Gender selector hit-test bug, and establish a reusable `BiteTopBar` primitive that codifies the project's top safe area rules so future pages follow them by default.

## Background

Three issues observed today:

1. **Onboarding back button** sits at `safe-area-top + 4pt` with a 36pt touch target — overlaps the Dynamic Island region on modern iPhones and is too small to tap reliably.
2. **Gender selector** registers a visual selection only for `.female`. Other options receive the tap but the row's red border + checkmark never appears. Suspected hit-test/binding glitch in the custom layout.
3. **Procedural orb** in `BiteOrbView` is a stylized red circle with white-dot eyes — no longer matches the chosen mascot identity (`biteorbs.png`, a glassy bitten apple with eyes).

The project also lacks a single source of truth for top-bar dimensions. The user provided explicit rules (56pt buttons, 24pt horizontal padding, `safe-area + 12pt` offset, 150pt reserved top zone) that should be encoded once and applied everywhere top chrome appears.

## Non-goals

- Migrating non-onboarding pages (Today, Coach, Files, modal sheets) to `BiteTopBar`. The new component is built reusable but Phase 1 only applies it to `OnboardingView`. Other pages remain on their existing chrome.
- Replacing the `BiteLogo` "B" mark image — it's a brand mark with a different role from the orb mascot. Stays as-is.
- Generating additional custom illustrations for onboarding pages (e.g., `charts.png`, `health-heart.pdf`). Existing SF Symbols stay.
- Adding multi-state mascot variants (happy, thinking, sleeping). Phase 1 ships a single static PNG; state is communicated via a halo + breathe SwiftUI overlay.

## Architecture

### New files

- `Bite/Assets.xcassets/BiteOrbs.imageset/` — single-scale @1x raster, 1254×1254 PNG (transparent background).
- `Bite/Design/BiteOrbImage.swift` — wrapper view that renders `Image("BiteOrbs")` with optional halo, breathe scale, hover offset. Reuses existing `OrbMood` and `OrbState` enums to drive halo color/intensity. Lives in `Design/` (not `Views/Coach/`) because Phase 1 already uses it from Welcome, Today, and Coach.
- `Bite/Design/BiteTopBar.swift` — reusable top bar primitive. Encodes the project's safe area rules.

### Removed files

- `Bite/Views/Coach/BiteOrbView.swift` — superseded by `BiteOrbImage`.

### Edited files

- `Bite/Design/BiteThemeTokens.swift` — adds top-bar dimension constants.
- `Bite/Views/Onboarding/Components/OnboardingProgressBar.swift` — rewrite as segmented bar.
- `Bite/Views/Onboarding/OnboardingView.swift` — uses `BiteTopBar`, drops custom navBar + bottom progress.
- `Bite/Views/Onboarding/Components/OnboardingScaffold.swift` — drops top `Spacer(minLength: 4)` (top spacing is now managed by parent).
- `Bite/Views/Onboarding/GenderView.swift` — rewritten on top of `OnboardingScaffold` with a single-row Button, `.contentShape(Rectangle())`, and a separated `GenderRow` subview.
- `Bite/Views/Onboarding/WelcomeView.swift` — replaces hand-built procedural orb with `BiteOrbImage(size: 200, showHalo: true)`.
- `Bite/Views/Coach/CoachView.swift` — both `BiteOrbView(size: 32, ...)` and `BiteOrbView(size: 130, ...)` swapped for `BiteOrbImage`.
- `Bite/Views/Today/AskBitePill.swift` — `MicroOrb` private struct removed; replaced by `BiteOrbImage(size: 24, showHalo: false)`.

## Components

### `BiteOrbImage`

```swift
struct BiteOrbImage: View {
    var size: CGFloat = 130
    var mood: OrbMood = .neutral
    var state: OrbState = .idle
    var showHalo: Bool = true
}
```

- Body: `ZStack` with optional radial-gradient halo (`mood`-tinted) behind `Image("BiteOrbs").resizable().scaledToFit()`.
- Animation: same breathe + hover behavior currently in `BiteOrbView` (idle slow, thinking/listening fast). Moved verbatim into the new wrapper.
- `OrbPalette.palette(for: mood)` continues to drive halo tint. The PNG itself is unchanged across moods (Phase 1 limitation).
- `showHalo: false` is used for sub-32pt usages (AskBitePill micro) where the halo would be a noisy blur.

### `BiteTopBar<Trailing>`

```swift
struct BiteTopBar<Trailing: View>: View {
    let onBack: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing
}
```

- Layout: `HStack(spacing: 12)` with the back button (when present) on the leading edge and the `trailing` slot filling the remainder.
- Back button: 56×56 circle, `.ultraThinMaterial` background, `chevron.left` font 18pt semibold, `Color.black.opacity(0.06)` 1pt stroke, light haptic on tap, accessibility label "Back".
- When `onBack == nil` the leading slot is hidden (zero width) but the row still occupies 56pt vertically so content below doesn't shift between welcome (no back) and other pages.
- Top inset: `safeAreaTop + BiteTheme.topBarTopOffset` (12pt). Achieved with `safeAreaInset(edge: .top)` or a `GeometryReader` reading `safeAreaInsets.top` — implementer picks whichever produces a stable layout under keyboard and rotation. Document the choice in code.
- Horizontal padding: 24pt.

### `SegmentedProgressBar`

Rewrites `OnboardingProgressBar`.

```swift
struct SegmentedProgressBar: View {
    let total: Int
    let current: Int
}
```

- HStack of `total` rounded rectangles, each `maxWidth: .infinity`, height 4pt, corner radius 2pt, spacing 4pt.
- Segments at index `< current`: `.biteRed` fill. Segments at index `>= current`: `Color.black.opacity(0.08)` fill.
- Animated with `BiteMotion.progressBar` on `current` change.
- Hidden on `current == 0` (welcome). The bar itself returns `EmptyView` when `current == 0`; the `trailing` slot in `BiteTopBar` then collapses to nothing while the row keeps its 56pt height.

### `BiteTheme` additions

```swift
enum BiteTheme {
    // existing...
    static let topBarButtonSize: CGFloat = 56
    static let topBarHorizontalPadding: CGFloat = 24
    static let topBarTopOffset: CGFloat = 12
    static let reservedTopZone: CGFloat = 150
}
```

These are referenced by `BiteTopBar` and by `OnboardingView`'s `pageContent` top padding.

## Layout rules (codified)

For any page using `BiteTopBar`:

- Top bar row: 56pt tall, positioned at `y = safeAreaTop + 12`.
- The row's bottom edge sits around `y ≈ safeAreaTop + 12 + 56 ≈ 100pt` on a typical device (varies by safe area).
- **Reserved top zone** ends at `y = 150pt` minimum.
- Page content starts at `y >= 150pt`. `OnboardingView` enforces this by giving `pageContent` a `padding(.top, max(0, BiteTheme.reservedTopZone - safeAreaTop - BiteTheme.topBarButtonSize - BiteTheme.topBarTopOffset))` so the gap absorbs different safe-area heights cleanly.
- No content, decorative element, or interactive element may render in the area above `y = 150pt` aside from the top bar itself.

## Bug fixes

### Gender selector

Two changes that together should resolve the hit-test bug:

1. **Migrate to `OnboardingScaffold`**, eliminating the custom `VStack` chrome. The scaffold is used by most other onboarding pages and is known to behave correctly.
2. **Extract `GenderRow` subview** with `.contentShape(Rectangle())` on the row content. The full-row hit area is then guaranteed regardless of what the inner HStack lays out.

If the bug persists after these changes, add a temporary `print("[Gender] tap:", gender)` in `GenderRow.onTap` during the simulator validation step, identify the root cause, fix it, and remove the print before commit. Don't merge with the print left in.

### Back button reachability

Solved structurally by moving onboarding chrome into `BiteTopBar`. Hit area becomes 56×56 (vs 36×36 before) and vertical position becomes `safeAreaTop + 12` (vs `4`), clearing the Dynamic Island.

## Animations

No new animation primitives. All motion reuses the existing `BiteMotion` constants:

- `BiteMotion.orbBreathe` / `orbBreatheFast` / `orbPulse` / `orbPulseSlow` — for `BiteOrbImage` halo + scale.
- `BiteMotion.progressBar` — for segmented bar fill on page change.
- `BiteMotion.onboardingPage` — page transition (unchanged).

## Validation

### Build
- `mcp__xcodebuildmcp__build_sim` (scheme `Bite`) — must compile clean, no warnings introduced.

### Visual smoke (simulator screenshots)
Boot a simulator, install the build, drive the app and capture screenshots at:

1. **Welcome** — orb is the PNG; no back button visible; no progress bar visible; row reserves 56pt.
2. **HealthKit page (page 1)** — back button on left as 56×56 glass circle; segmented progress bar on the right with 1 segment red, rest grey; hero icon starts at `y >= 150pt`.
3. **Gender** — page renders inside scaffold; tapping each row turns it red with checkmark; Continue button enables only after selection.
4. **Coach hero** (open chat from AskBitePill) — central orb is the PNG; halo pulses.
5. **AskBite collapsed pill** (Today) — micro-orb on the left of placeholder is the PNG (no halo).

### Bug verification
- Tap Male / Other / Prefer-not-to-say in turn. Each leaves the row visibly selected (red border + checkmark) and the Continue button enabled.
- Tap-test the back button on page 1: the entire 56×56 area triggers navigation; the area at `y < safeAreaTop + 12` does not.

### Tests
- Existing unit/UI tests must continue to pass. No new tests added; this is view-layer refactor with no business logic changes.

## Risks & mitigations

- **`biteorbs.png` PNG quality at 24pt** — 1254×1254 source resampled down to 24pt is small but should still be sharp on Retina (3x → 72pt actual pixels). If aliasing appears, mitigation is to render with `.interpolation(.high)` on `Image`. Verified during visual smoke.
- **Top-bar `safeAreaInset` interaction with `ScrollView`** — onboarding pages are mostly static content, no scrollview, so this is low-risk. If a future page nests a scrollview inside the scaffold, document the interaction at that point.
- **Gender bug not fully resolved by scaffold migration** — covered by the temporary-print fallback in the bug-fix section.

## Implementation order (for the plan that follows)

1. Add `biteorbs.png` to `Assets.xcassets` as `BiteOrbs.imageset`.
2. Add `BiteTheme` constants.
3. Build `BiteOrbImage`. Delete `BiteOrbView`.
4. Build `BiteTopBar`.
5. Rewrite `OnboardingProgressBar` as `SegmentedProgressBar`.
6. Refactor `OnboardingView` to use `BiteTopBar` + the new bar.
7. Migrate `GenderView` to `OnboardingScaffold` with `GenderRow`.
8. Swap orb call-sites in `WelcomeView`, `CoachView`, `AskBitePill`.
9. Visual smoke + bug verification on simulator.
10. Commit.
