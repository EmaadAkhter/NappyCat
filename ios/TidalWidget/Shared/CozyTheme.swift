import SwiftUI

/// Trimmed copy of lib/theme/cozy_colors.dart. Duplicated deliberately: the
/// widget extension cannot import Dart, and a widget rendering in slightly
/// different creams next to the app looks broken.
enum CozyTheme {
    static let pageBackground = Color(hex: 0xF5EDE0)
    static let cardBackground = Color(hex: 0xFFFDF7)
    static let cardSecondary  = Color(hex: 0xF8F0E5)
    static let textPrimary    = Color(hex: 0x4A3525)
    static let textSecondary  = Color(hex: 0x6B5545)
    static let textMuted      = Color(hex: 0x998475)
    static let sageGreen      = Color(hex: 0xA8C3A8)
    static let dustyPink      = Color(hex: 0xE8B4B8)
    static let softBlue       = Color(hex: 0x9BB7D4)
    static let softYellow     = Color(hex: 0xF3D58C)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Asset naming must match lib/models/cat_breed.dart: {breedId}_{awake|asleep}.
enum CatArt {
    static let known = ["tabby","tuxedo","ginger","pumpkin","koala","jester","blueberry","catear"]

    static func name(catId: String?, awake: Bool) -> String {
        let id = known.contains(catId ?? "") ? catId! : "tabby"
        return "\(id)_\(awake ? "awake" : "asleep")"
    }
}
