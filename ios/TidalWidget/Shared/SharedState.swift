import Foundation
import WidgetKit

/// The Swift half of the shared-cache contract. Must stay in step with
/// lib/models/widget_payload.dart — Flutter is the only writer of `tidal_state`,
/// the widget is the only writer of `tidal_pending_open`.
///
/// The widget never talks to Firestore: it has no auth and no SDK. Everything it
/// knows arrives through this blob.
enum LetterState: String {
    case empty, waiting, open, faded
}

struct TidalState {
    var state: LetterState = .empty
    var messageId: String?
    /// Present whenever a letter exists, INCLUDING while waiting. Rendering is
    /// gated on `state`, never on the presence of this — that is what lets the
    /// cat wake instantly on tap without a network round trip.
    var text: String?
    var openedAt: Date?
    var expiresAt: Date?
    var partnerName: String?
    var partnerCatId: String?
    var idleLine: String?

    /// Client-side expiry. The cached blob can outlive its own window, so never
    /// trust `state` alone.
    func effectiveState(now: Date = Date()) -> LetterState {
        if state == .open, let e = expiresAt, now >= e { return .faded }
        return state
    }
}

enum SharedStore {
    static let appGroup = "group.com.mypeblo.tidal"
    static let stateKey = "tidal_state"
    static let pendingOpenKey = "tidal_pending_open"
    static let widgetKind = "TidalWidget"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    private static func date(_ v: Any?) -> Date? {
        guard let ms = v as? Double, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    static func load() -> TidalState {
        guard let raw = defaults?.string(forKey: stateKey),
              let data = raw.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return TidalState() }

        return TidalState(
            state: LetterState(rawValue: j["state"] as? String ?? "") ?? .empty,
            messageId: j["messageId"] as? String,
            text: j["text"] as? String,
            openedAt: date(j["openedAtMs"]),
            expiresAt: date(j["expiresAtMs"]),
            partnerName: j["partnerName"] as? String,
            partnerCatId: j["partnerCatId"] as? String,
            idleLine: j["idleLine"] as? String
        )
    }

    /// Local acknowledgement of a tap: the letter will be read in the app, so
    /// the widget's cat goes straight back to sleep, and the breadcrumb tells
    /// Flutter which letter to open and show.
    static func markTappedLocally() {
        guard let d = defaults,
              let raw = d.string(forKey: stateKey),
              let data = raw.data(using: .utf8),
              var j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (j["state"] as? String) == LetterState.waiting.rawValue,
              let messageId = j["messageId"] as? String
        else { return }

        let nowMs = Date().timeIntervalSince1970 * 1000
        j["state"] = LetterState.empty.rawValue

        if let out = try? JSONSerialization.data(withJSONObject: j),
           let s = String(data: out, encoding: .utf8) {
            d.set(s, forKey: stateKey)
        }

        // Written even if the state write above failed — losing the breadcrumb
        // means the open never reaches Firestore and the partner never sees it.
        if let crumb = try? JSONSerialization.data(withJSONObject: [
            "messageId": messageId,
            "tappedAtMs": nowMs,
        ]), let s = String(data: crumb, encoding: .utf8) {
            d.set(s, forKey: pendingOpenKey)
        }
    }

    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
