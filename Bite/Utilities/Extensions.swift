import SwiftUI
import UIKit

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var shortFormatted: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: self)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Color {
    static let biteRed = Color(red: 0.93, green: 0.26, blue: 0.26)
    static let biteOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let biteBlue = Color(red: 0.25, green: 0.52, blue: 1.0)
    static let bitePurple = Color(red: 0.58, green: 0.34, blue: 0.92)
    static let biteBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemBackground
            : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    })
    static let biteAccent = Color(red: 0.93, green: 0.26, blue: 0.26)
}
