import SwiftUI
import UIKit

/// Observes the system keyboard show/hide notifications and publishes height +
/// visibility. Inject via `@Environment(\.keyboard)` so any view in the shell
/// can react (e.g., the AskBite pill docks above the keyboard when shown).
@MainActor
@Observable
final class KeyboardObserver {
    var keyboardHeight: CGFloat = 0
    var isVisible: Bool = false

    init() {
        let nc = NotificationCenter.default
        nc.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
            Task { @MainActor in
                self.keyboardHeight = frame.height
                self.isVisible = true
            }
        }
        nc.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.keyboardHeight = 0
                self.isVisible = false
            }
        }
    }
}

private struct KeyboardObserverKey: EnvironmentKey {
    @MainActor static var defaultValue: KeyboardObserver = KeyboardObserver()
}

extension EnvironmentValues {
    var keyboard: KeyboardObserver {
        get { self[KeyboardObserverKey.self] }
        set { self[KeyboardObserverKey.self] = newValue }
    }
}
