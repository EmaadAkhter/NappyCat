import AppIntents
import WidgetKit

/// Fired by tapping the widget. Salvaged shape from WakeCatIntent: write the
/// App Group, reload the timeline.
///
/// It never touches Firestore — no auth, no SDK in an extension. It flips the
/// local cache so the cat wakes instantly, drops a breadcrumb, and opens the
/// app, which is what actually reaches the server. See WidgetBridge
/// .reconcilePendingOpen on the Dart side.
struct OpenLetterIntent: AppIntent {
    static var title: LocalizedStringResource = "Read the letter"
    static var description = IntentDescription("Wakes the cat and opens your letter.")

    /// The tap IS the app opening, which is what makes the "user only ever taps
    /// the widget" case impossible.
    static var openAppWhenRun: Bool = true

    /// Kept in step with Config.openTtl on the Dart side. Flutter owns the real
    /// constant; this is the optimistic local guess until the app reconciles,
    /// so a mismatch self-corrects within seconds rather than corrupting state.
    @Parameter(title: "Open TTL seconds")
    var ttlSeconds: Double?

    init() {}

    func perform() async throws -> some IntentResult {
        let s = SharedStore.load()

        // Nothing waiting: wake the cat for an idle line only. No breadcrumb, so
        // the app has nothing to flush.
        if s.effectiveState() == .waiting {
            SharedStore.markOpenedLocally(ttl: ttlSeconds ?? 16 * 60 * 60)
        }

        SharedStore.reload()
        return .result()
    }
}
