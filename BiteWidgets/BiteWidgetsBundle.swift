import WidgetKit
import SwiftUI

@main
struct BiteWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyOverviewWidget()
        HealthMonitorWidget()
        EnergyBankWidget()
        HydrationWidget()
        MacrosWidget()
    }
}
