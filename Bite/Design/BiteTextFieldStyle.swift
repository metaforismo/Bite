import SwiftUI

/// Themed text field style: animated focus ring, optional error state,
/// configurable prefix/suffix slots. Replaces the default SwiftUI styling
/// scattered across forms and onboarding.
struct BiteTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    var hasError: Bool = false
    var leading: AnyView? = nil
    var trailing: AnyView? = nil

    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: 10) {
            if let leading {
                leading.foregroundStyle(.biteInkFaint)
            }
            configuration
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.biteInk)
                .focused($isFocused)
            if let trailing {
                trailing.foregroundStyle(.biteInkFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.18), value: hasError)
    }

    private var borderColor: Color {
        if hasError { return .biteRed }
        if isFocused { return .biteInk.opacity(0.5) }
        return .black.opacity(0.08)
    }

    private var borderWidth: CGFloat {
        (hasError || isFocused) ? 1.5 : 1
    }
}

extension TextFieldStyle where Self == BiteTextFieldStyle {
    static var bite: BiteTextFieldStyle { BiteTextFieldStyle() }
    static func bite(error: Bool) -> BiteTextFieldStyle { BiteTextFieldStyle(hasError: error) }
}
