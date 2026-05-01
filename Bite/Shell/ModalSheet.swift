import SwiftUI

/// Generic modal sheet host for V2 — every interactive popover (Hydration,
/// Caffeine, Activity Status, Smart Alarm, Menstrual Log, Plate Calculator,
/// Strength Exercise Library) routes through this enum. The shell scales the
/// home/route layer behind it (0.94 + 8px blur) so depth feels physical, then
/// slides the sheet up from the bottom in the same `BiteMotion.routeSheet`
/// curve Coach and Files already use.
enum ModalSheet: Identifiable, Hashable {
    case hydration
    case caffeine
    case activityStatus
    case smartAlarm
    case sleepDial
    case menstrualLog
    case strengthExerciseLibrary

    var id: String {
        switch self {
        case .hydration: return "hydration"
        case .caffeine: return "caffeine"
        case .activityStatus: return "activityStatus"
        case .smartAlarm: return "smartAlarm"
        case .sleepDial: return "sleepDial"
        case .menstrualLog: return "menstrualLog"
        case .strengthExerciseLibrary: return "strengthExerciseLibrary"
        }
    }
}
