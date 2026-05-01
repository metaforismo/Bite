import WidgetKit

struct BiteSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: BiteWidgetSnapshot
}

struct BiteSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> BiteSnapshotEntry {
        BiteSnapshotEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (BiteSnapshotEntry) -> Void) {
        completion(BiteSnapshotEntry(date: Date(), snapshot: BiteWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BiteSnapshotEntry>) -> Void) {
        let entry = BiteSnapshotEntry(date: Date(), snapshot: BiteWidgetSnapshot.load())
        // Refresh every 30 minutes — the main app calls
        // `WidgetCenter.reloadAllTimelines()` when Today refreshes, so this
        // is just the long-tail fallback.
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
