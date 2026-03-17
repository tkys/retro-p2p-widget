import WidgetKit
import SwiftUI

struct RetroClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: .now, skin: SkinLoader.defaultSkin())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let skin = SkinLoader.selectedSkin()
        completion(ClockEntry(date: .now, skin: skin))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let skin = SkinLoader.selectedSkin()
        let now = Date()
        let calendar = Calendar.current

        // Generate entries for the next 60 minutes (one per minute)
        var entries: [ClockEntry] = []
        for minuteOffset in 0..<60 {
            guard let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) else { continue }
            entries.append(ClockEntry(date: entryDate, skin: skin))
        }

        let nextUpdate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RetroClockWidgetEntryView: View {
    var entry: RetroClockProvider.Entry

    var body: some View {
        RetroClockView(entry: entry)
    }
}

struct RetroClockWidget: Widget {
    let kind: String = "RetroClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RetroClockProvider()) { entry in
            RetroClockWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Retro Clock")
        .description("A retro-style clock widget with customizable skins.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct RetroClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        RetroClockWidget()
    }
}
