import AppIntents
import WidgetKit

/// Tap on the widget = read the letter RIGHT THERE. The app is deliberately
/// not launched; the reveal happens on the widget and Flutter flushes the real
/// open to Firestore next time it runs.
struct OpenLetterIntent: AppIntent {
    static var title: LocalizedStringResource = "Read the letter"
    static var description = IntentDescription("Reveals the letter on the widget.")

    /// Reading happens on the home screen — do not drag the user into the app.
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        let s = SharedStore.load()

        if s.effectiveState() == .waiting {
            // The app republishes the authoritative window when it next runs,
            // so a dev/prod mismatch self-corrects.
            SharedStore.markOpenedLocally(readingWindow: 10 * 60)
        }

        SharedStore.reload()
        return .result()
    }
}
