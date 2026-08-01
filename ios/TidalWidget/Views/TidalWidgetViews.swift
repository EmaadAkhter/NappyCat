import SwiftUI
import WidgetKit

/// Layouts salvaged from NapCatWidgetViews.swift. The cat shown is the
/// PARTNER's: the widget is "them, on your home screen" — asleep when quiet,
/// awake when they have spoken.
struct TidalWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TidalEntry

    var body: some View {
        Button(intent: OpenLetterIntent()) {
            switch family {
            case .systemMedium: MediumView(entry: entry)
            case .accessoryCircular: CircularView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            default: SmallView(entry: entry)
            }
        }
        .buttonStyle(.plain)
        .containerBackground(CozyTheme.cardBackground, for: .widget)
    }
}

private func cat(_ entry: TidalEntry, size: CGFloat) -> some View {
    // Awake = an unread letter waits. Reading happens in the app; once read
    // the cat sleeps again.
    Image(CatArt.name(catId: entry.state.partnerCatId,
                      awake: entry.resolved == .waiting || entry.resolved == .open))
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
}

private func partner(_ entry: TidalEntry) -> String {
    entry.state.partnerName ?? "Someone"
}

/// Comic speech bubble with a tail pointing left at the cat.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 9
        var p = Path(roundedRect: CGRect(x: tail, y: 0,
                                         width: rect.width - tail,
                                         height: rect.height),
                     cornerRadius: 14)
        let cy = rect.height * 0.45
        p.move(to: CGPoint(x: tail + 1, y: cy - tail))
        p.addLine(to: CGPoint(x: 0, y: cy))
        p.addLine(to: CGPoint(x: tail + 1, y: cy + tail))
        p.closeSubpath()
        return p
    }
}

private func bubble(_ text: String, size: CGFloat) -> some View {
    Text(text)
        .font(.system(size: size, weight: .medium, design: .rounded))
        .foregroundColor(CozyTheme.textPrimary)
        .padding(.leading, 19)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(BubbleShape().fill(CozyTheme.cardSecondary))
        .overlay(BubbleShape().stroke(CozyTheme.sageGreen.opacity(0.5), lineWidth: 1.5))
}

// MARK: - Small

struct SmallView: View {
    let entry: TidalEntry

    var body: some View {
        VStack(spacing: 6) {
            cat(entry, size: 96)

            switch entry.resolved {
            case .open, .waiting:
                // The letter itself, comic-style, right on the home screen.
                Text(entry.state.text ?? "")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(CozyTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                Text("— \(partner(entry))")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(CozyTheme.textMuted)
            case .faded:
                Text("it drifted away")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(CozyTheme.textMuted)
            case .empty:
                Text(entry.state.idleLine ?? "all quiet")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(CozyTheme.textMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(10)
    }
}

// MARK: - Medium

struct MediumView: View {
    let entry: TidalEntry

    var body: some View {
        HStack(spacing: 14) {
            cat(entry, size: 118)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(partner(entry))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(CozyTheme.textPrimary)
                    Spacer()
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(CozyTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor)
                        .cornerRadius(10)
                }

                switch entry.resolved {
                case .open, .waiting:
                    bubble(entry.state.text ?? "", size: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .faded:
                    bubble("it drifted away…", size: 12)
                case .empty:
                    bubble(entry.state.idleLine ?? "zzz…", size: 11)
                }
            }
        }
        .padding(14)
    }

    private var badge: String {
        switch entry.resolved {
        case .open, .waiting: return "✉️ NEW"
        case .faded: return "FADED 🌙"
        case .empty: return "ASLEEP 💤"
        }
    }

    private var badgeColor: Color {
        switch entry.resolved {
        case .open: return CozyTheme.dustyPink
        case .waiting: return CozyTheme.softYellow
        default: return CozyTheme.softBlue.opacity(0.6)
        }
    }
}

// MARK: - Lock screen

struct CircularView: View {
    let entry: TidalEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            cat(entry, size: 42)
        }
    }
}

struct RectangularView: View {
    let entry: TidalEntry

    var body: some View {
        HStack(spacing: 8) {
            cat(entry, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(partner(entry))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                // Lock screen is visible without unlocking, so a waiting letter
                // shows only that it exists — never its text.
                switch entry.resolved {
                case .open, .waiting:
                    // Lock screen is visible without unlocking; show that a
                    // letter exists, never its words.
                    Text("left you something").font(.system(size: 10))
                case .faded:
                    Text("it drifted away").font(.system(size: 10))
                case .empty:
                    Text("all quiet").font(.system(size: 10))
                }
            }
        }
    }
}
