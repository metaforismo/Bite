import SwiftUI

/// Fixed top chrome row used across pages that need a back button, a progress
/// indicator, or a close action. Encodes the project's top safe-area rules
/// in one place so every page stays consistent:
///
/// - Row height: `BiteTheme.topBarButtonSize` (56pt)
/// - Top offset: `safe-area-top + BiteTheme.topBarTopOffset` (12pt)
/// - Horizontal padding: `BiteTheme.topBarHorizontalPadding` (24pt)
///
/// The row reserves its 56pt height even when no back button is shown, so
/// content below doesn't shift when navigating between pages with and
/// without back affordance.
///
/// `trailing` is a free-form slot for a progress bar, a close action, or
/// nothing. It is vertically centered on the 56pt row.
struct BiteTopBar<Trailing: View>: View {
    let onBack: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    init(
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                Button {
                    BiteHaptics.impact(.light)
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.biteInk)
                        .frame(
                            width: BiteTheme.topBarButtonSize,
                            height: BiteTheme.topBarButtonSize
                        )
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                // Reserve the same width so the trailing slot doesn't reflow
                // when the back button toggles between pages.
                Color.clear
                    .frame(
                        width: BiteTheme.topBarButtonSize,
                        height: BiteTheme.topBarButtonSize
                    )
                    .accessibilityHidden(true)
            }

            trailing()
                .frame(maxWidth: .infinity)
        }
        .frame(height: BiteTheme.topBarButtonSize)
        .padding(.horizontal, BiteTheme.topBarHorizontalPadding)
        .padding(.top, BiteTheme.topBarTopOffset)
    }
}

#Preview("With back + progress") {
    ZStack {
        BiteGradientBackground(style: .today)
        VStack(spacing: 0) {
            BiteTopBar(onBack: {}) {
                Capsule().fill(Color.biteRed).frame(height: 4)
            }
            Spacer()
        }
    }
}

#Preview("No back") {
    ZStack {
        BiteGradientBackground(style: .today)
        VStack(spacing: 0) {
            BiteTopBar(onBack: nil) { EmptyView() }
            Spacer()
        }
    }
}
