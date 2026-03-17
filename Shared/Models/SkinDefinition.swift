import SwiftUI

struct SkinDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let background: Background
    let border: Border
    let clock: ClockStyle
    let decorations: [Decoration]
    let images: SkinImages?

    struct Background: Codable, Hashable {
        let color: String
    }

    struct Border: Codable, Hashable {
        let color: String
        let width: CGFloat
    }

    struct ClockStyle: Codable, Hashable {
        let style: String // "digital" or "sprite"
        let font: String?
        let color: String
        let position: Position
        let scale: CGFloat?
    }

    struct Position: Codable, Hashable {
        let x: CGFloat
        let y: CGFloat
    }

    struct Decoration: Codable, Hashable {
        let type: String
        let color: String
        let from: [CGFloat]?
        let to: [CGFloat]?
        let text: String?
        let position: Position?
        let fontSize: CGFloat?
    }

    struct SkinImages: Codable, Hashable {
        let directory: String
        let background: String?
        let numbers: String?
        let titlebar: String?
        let digitWidth: CGFloat?
        let digitHeight: CGFloat?
    }
}

extension SkinDefinition {
    var backgroundColor: Color {
        Color(hex: background.color)
    }

    var borderColor: Color {
        Color(hex: border.color)
    }

    var clockColor: Color {
        Color(hex: clock.color)
    }

    var hasImageAssets: Bool {
        images != nil
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
