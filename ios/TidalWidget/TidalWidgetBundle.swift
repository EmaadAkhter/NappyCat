import WidgetKit
import SwiftUI

@main
struct TidalWidgetBundle: WidgetBundle {
    var body: some Widget { TidalWidget() }
}

struct TidalWidget: Widget {
    // Must match SharedStore.widgetKind and the iOSName passed to
    // HomeWidget.updateWidget on the Dart side. A mismatch fails SILENTLY —
    // the widget simply never refreshes.
    let kind = SharedStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TidalTimelineProvider()) { entry in
            TidalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tidal")
        .description("Their cat sleeps here until a letter arrives. Tap to read it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
