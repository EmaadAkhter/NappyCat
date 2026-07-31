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
    Image(CatArt.name(catId: entry.state.partnerCatId, awake: entry.resolved == .open))
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
}

private func partner(_ entry: TidalEntry) -> String {
    entry.state.partnerName ?? "Someone"
}

// MARK: - Small

struct SmallView: View {
    let entry: TidalEntry

    var body: some View {
        VStack(spacing: 6) {
            cat(entry, size: 76)

            switch entry.resolved {
            case .open:
                // The only state that renders the body.
                Text(entry.state.text ?? "")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(CozyTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            case .waiting:
                Text("\(partner(entry)) left you something")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(CozyTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("tap to read")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
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
            cat(entry, size: 94)

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
                case .open:
                    Text(entry.state.text ?? "")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CozyTheme.textPrimary)
                        .padding(10)
                        .background(CozyTheme.cardSecondary)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(CozyTheme.sageGreen.opacity(0.5), lineWidth: 1.5)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .waiting:
                    Text("A letter is waiting. Tap to read it — it fades 16 hours after you open it.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(CozyTheme.textSecondary)
                case .faded:
                    Text("That letter has faded.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CozyTheme.textSecondary)
                case .empty:
                    Text(entry.state.idleLine ?? "Nothing yet. All quiet.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(CozyTheme.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(14)
    }

    private var badge: String {
        switch entry.resolved {
        case .open: return "READING 💖"
        case .waiting: return "✉️ WAITING"
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
                case .open:
                    Text(entry.state.text ?? "").font(.system(size: 10)).lineLimit(1)
                case .waiting:
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
