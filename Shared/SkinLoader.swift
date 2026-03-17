import Foundation

struct SkinLoader {
    static let allSkinNames = ["winamp-classic", "njoy-green", "dark-materia", "vaporwave"]

    static func loadAll(from bundle: Bundle = .main) -> [SkinDefinition] {
        allSkinNames.compactMap { load(named: $0, from: bundle) }
    }

    static func load(named name: String, from bundle: Bundle = .main) -> SkinDefinition? {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Skins")
                ?? bundle.url(forResource: name, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SkinDefinition.self, from: data)
    }

    static func defaultSkin() -> SkinDefinition {
        SkinDefinition(
            id: "winamp-classic",
            name: "Winamp Classic",
            background: .init(color: "#2B2B2B"),
            border: .init(color: "#4A4A4A", width: 1),
            clock: .init(style: "digital", font: "Menlo-Bold", color: "#00FF00", position: .init(x: 0.5, y: 0.5), scale: nil),
            decorations: [],
            images: nil
        )
    }

    static var selectedSkinID: String {
        get {
            UserDefaults(suiteName: "group.com.retropwidget")?.string(forKey: "selectedSkinID") ?? "winamp-classic"
        }
        set {
            UserDefaults(suiteName: "group.com.retropwidget")?.set(newValue, forKey: "selectedSkinID")
        }
    }

    static func selectedSkin(from bundle: Bundle = .main) -> SkinDefinition {
        load(named: selectedSkinID, from: bundle) ?? defaultSkin()
    }
}
