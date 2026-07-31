import WidgetKit
import SwiftUI

struct TidalEntry: TimelineEntry {
    let date: Date
    let state: TidalState
    /// Already resolved for `date`, so the view never recomputes expiry.
    let resolved: LetterState
}

/// Salvaged from NapCatTimelineProvider, which already had the two-entry shape
/// this needs — only the constant and the data source changed.
///
/// The second entry is what makes expiry feel magical: WidgetKit renders the
/// letter now and the sleeping cat at expiresAt, so the cat falls asleep exactly
/// on time with the app never running and zero refresh budget spent.
struct TidalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TidalEntry {
        TidalEntry(date: Date(), state: TidalState(), resolved: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TidalEntry) -> Void) {
        let s = SharedStore.load()
        completion(TidalEntry(date: Date(), state: s, resolved: s.effectiveState()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TidalEntry>) -> Void) {
        let now = Date()
        let s = SharedStore.load()
        let resolved = s.effectiveState(now: now)

        var entries = [TidalEntry(date: now, state: s, resolved: resolved)]
        var policy: TimelineReloadPolicy = .never

        // Only an open letter has a scheduled future transition.
        if resolved == .open, let expires = s.expiresAt, expires > now {
            entries.append(TidalEntry(date: expires, state: s, resolved: .faded))
            policy = .after(expires)
        }

        completion(Timeline(entries: entries, policy: policy))
    }
}
