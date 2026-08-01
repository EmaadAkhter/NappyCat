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

    init() {}

    func perform() async throws -> some IntentResult {
        let s = SharedStore.load()

        if s.effectiveState() == .waiting {
            SharedStore.markTappedLocally()
        }

        SharedStore.reload()
        return .result()
    }
}
