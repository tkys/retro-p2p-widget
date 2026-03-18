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
        let dataSources = DataSource.loadAll()

        // If no data sources configured, skip network and return immediately
        guard !dataSources.isEmpty else {
            let entries = makeEntries(skin: skin, fetchedData: [:], from: now, calendar: calendar)
            let nextUpdate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            completion(Timeline(entries: entries, policy: .after(nextUpdate)))
            return
        }

        // Fetch data from configured sources
        Task {
            let fetchedData = await DataFetcher.fetchAll(sources: dataSources)
            let entries = makeEntries(skin: skin, fetchedData: fetchedData, from: now, calendar: calendar)
            // Shorter refresh interval when data sources are active (15 min)
            let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: entries, policy: .after(nextUpdate)))
        }
    }

    private func makeEntries(skin: SkinDefinition, fetchedData: [String: String], from now: Date, calendar: Calendar) -> [ClockEntry] {
        (0..<60).compactMap { minuteOffset in
            guard let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) else { return nil }
            return ClockEntry(date: entryDate, skin: skin, fetchedData: fetchedData)
        }
    }
}

struct RetroClockWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: RetroClockProvider.Entry

    var body: some View {
        RetroClockView(entry: entry, family: family)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct RetroClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        RetroClockWidget()
    }
}
