import Foundation

struct DataSource: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    var jsonPath: String?       // e.g. "$.data.temperature"
    var displayFormat: String?  // e.g. "{value}°F"
    var zone: DisplayZone

    enum DisplayZone: String, Codable, CaseIterable, Hashable {
        case marquee    // main window marquee area
        case eq         // EQ window area
        case playlist   // playlist window area
    }

    init(id: UUID = UUID(), name: String, url: URL, jsonPath: String? = nil, displayFormat: String? = nil, zone: DisplayZone = .playlist) {
        self.id = id
        self.name = name
        self.url = url
        self.jsonPath = jsonPath
        self.displayFormat = displayFormat
        self.zone = zone
    }
}

// MARK: - Persistence via App Group UserDefaults

extension DataSource {
    private static let suiteName = "group.com.retropwidget"
    private static let storageKey = "dataSources"

    static func loadAll() -> [DataSource] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([DataSource].self, from: data)) ?? []
    }

    static func saveAll(_ sources: [DataSource]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
