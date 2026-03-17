import SwiftUI
import WidgetKit

// Winamp classic skin fixed layout (275×116 canvas)
private enum WinampLayout {
    static let canvasWidth: CGFloat = 275
    static let canvasHeight: CGFloat = 116

    // Time display: #time container at (39, 26), 59×13
    // Center of time digits ≈ (68.5, 32.5)
    static let timeCenterX: CGFloat = 68.5
    static let timeCenterY: CGFloat = 32.5

    // Marquee: (111, 24), 154×6 → center (188, 27)
    static let marqueeCenterX: CGFloat = 188
    static let marqueeCenterY: CGFloat = 27

    // Kbps: (111, 43), 15×6 → center (118.5, 46)
    static let kbpsCenterX: CGFloat = 118.5
    static let kbpsCenterY: CGFloat = 46

    // Khz: (156, 43), 10×6 → center (161, 46)
    static let khzCenterX: CGFloat = 161
    static let khzCenterY: CGFloat = 46

    // Composed image sizes (from compose-skin.sh @2x)
    // Medium: 720×338, main scaled to 720 wide, centered vertically
    // Large:  720×752, main placed at top
    // Small:  338×338, left 130px of main cropped and stretched

    struct ImageLayout {
        let imageWidth: CGFloat
        let imageHeight: CGFloat
        let mainScale: CGFloat
        let mainOffsetX: CGFloat
        let mainOffsetY: CGFloat
    }

    static func layout(for family: WidgetFamily) -> ImageLayout {
        switch family {
        case .systemSmall:
            // Crop: left 130px of 275×116, stretched to 338×338
            let scaleX: CGFloat = 338.0 / 130.0  // 2.6
            let scaleY: CGFloat = 338.0 / 116.0  // 2.914
            return ImageLayout(imageWidth: 338, imageHeight: 338,
                               mainScale: scaleX, mainOffsetX: 0, mainOffsetY: 0)
        case .systemMedium:
            // main scaled to 720 wide: scale = 720/275 ≈ 2.618
            let scale: CGFloat = 720.0 / 275.0
            let scaledH = 116.0 * scale  // ≈ 303.7
            let yOffset = (338.0 - scaledH) / 2.0  // ≈ 17.1
            return ImageLayout(imageWidth: 720, imageHeight: 338,
                               mainScale: scale, mainOffsetX: 0, mainOffsetY: yOffset)
        case .systemLarge:
            // main scaled to 720 wide, placed at top (y=0)
            let scale: CGFloat = 720.0 / 275.0
            return ImageLayout(imageWidth: 720, imageHeight: 752,
                               mainScale: scale, mainOffsetX: 0, mainOffsetY: 0)
        default:
            let scale: CGFloat = 720.0 / 275.0
            return ImageLayout(imageWidth: 720, imageHeight: 338,
                               mainScale: scale, mainOffsetX: 0, mainOffsetY: 0)
        }
    }

    /// Convert Winamp canvas coordinates to relative position (0-1) for a given widget family
    static func relativePosition(canvasX: CGFloat, canvasY: CGFloat, family: WidgetFamily) -> CGPoint {
        let l = layout(for: family)

        if family == .systemSmall {
            // Small uses crop of left 130px, stretched non-uniformly
            let scaleX: CGFloat = 338.0 / 130.0
            let scaleY: CGFloat = 338.0 / 116.0
            let px = (canvasX * scaleX) / l.imageWidth
            let py = (canvasY * scaleY) / l.imageHeight
            return CGPoint(x: px, y: py)
        }

        let px = (canvasX * l.mainScale + l.mainOffsetX) / l.imageWidth
        let py = (canvasY * l.mainScale + l.mainOffsetY) / l.imageHeight
        return CGPoint(x: px, y: py)
    }
}

struct RetroClockView: View {
    let entry: ClockEntry
    let skin: SkinDefinition
    let family: WidgetFamily

    init(entry: ClockEntry, family: WidgetFamily = .systemMedium) {
        self.entry = entry
        self.skin = entry.skin
        self.family = family
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer(in: geo.size)

                if skin.hasImageAssets {
                    winampLayout(in: geo.size)
                } else {
                    textClockLayer(in: geo.size)
                }
            }
            .clipShape(ContainerRelativeShape())
            .overlay(
                ContainerRelativeShape()
                    .stroke(skin.borderColor, lineWidth: skin.border.width)
                    .padding(skin.border.width / 2)
            )
        }
    }

    // MARK: - Winamp Layout (auto-positioned)

    @ViewBuilder
    private func winampLayout(in size: CGSize) -> some View {
        let timePos = WinampLayout.relativePosition(
            canvasX: WinampLayout.timeCenterX,
            canvasY: WinampLayout.timeCenterY,
            family: family
        )

        // Sprite clock digits at Winamp time position
        if let images = skin.images,
           let numbersName = images.numbers,
           let spriteSheet = loadImage(named: numbersName, in: images.directory) {
            let digitW = images.digitWidth ?? 9
            let digitH = images.digitHeight ?? 13
            let scale = spriteScale(in: size)

            SpriteNumberView(
                timeString: formatTime(entry.date),
                spriteSheet: spriteSheet,
                digitWidth: digitW,
                digitHeight: digitH,
                scale: scale
            )
            .position(
                x: size.width * timePos.x,
                y: size.height * timePos.y
            )
        }

        // Marquee area: show date
        let marqueePos = WinampLayout.relativePosition(
            canvasX: WinampLayout.marqueeCenterX,
            canvasY: WinampLayout.marqueeCenterY,
            family: family
        )
        Text(entry.date, style: .date)
            .font(.system(size: marqueeFont, design: .monospaced))
            .foregroundStyle(skin.clockColor)
            .lineLimit(1)
            .position(
                x: size.width * marqueePos.x,
                y: size.height * marqueePos.y
            )

        // Kbps area: show day of week
        let kbpsPos = WinampLayout.relativePosition(
            canvasX: WinampLayout.kbpsCenterX,
            canvasY: WinampLayout.kbpsCenterY,
            family: family
        )
        Text(dayOfWeek(entry.date))
            .font(.system(size: subInfoFont, design: .monospaced))
            .foregroundStyle(skin.clockColor.opacity(0.8))
            .position(
                x: size.width * kbpsPos.x,
                y: size.height * kbpsPos.y
            )
    }

    private var marqueeFont: CGFloat {
        switch family {
        case .systemSmall:  return 9
        case .systemMedium: return 10
        case .systemLarge:  return 12
        default: return 10
        }
    }

    private var subInfoFont: CGFloat {
        switch family {
        case .systemSmall:  return 7
        case .systemMedium: return 8
        case .systemLarge:  return 10
        default: return 8
        }
    }

    private func spriteScale(in size: CGSize) -> CGFloat {
        let l = WinampLayout.layout(for: family)
        // Scale sprite digits to match how main.bmp was scaled in the composed image
        // Then adjust for actual widget size vs composed image size
        let composedScale = l.mainScale
        let widgetToImageRatio = size.width / l.imageWidth
        return composedScale * widgetToImageRatio
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(in size: CGSize) -> some View {
        if let bgImage = loadSizedBackground() {
            Image(uiImage: bgImage)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            skin.backgroundColor
        }
    }

    private func loadSizedBackground() -> UIImage? {
        guard let images = skin.images else { return nil }

        let sizedName: String? = switch family {
        case .systemSmall:  images.backgroundSmall ?? "bg-small.png"
        case .systemMedium: images.backgroundMedium ?? "bg-medium.png"
        case .systemLarge:  images.backgroundLarge ?? "bg-large.png"
        default:            images.background
        }

        if let name = sizedName, let img = loadImage(named: name, in: images.directory) {
            return img
        }
        if let bg = images.background {
            return loadImage(named: bg, in: images.directory)
        }
        return nil
    }

    // MARK: - Text Clock (fallback for non-image skins)

    @ViewBuilder
    private func textClockLayer(in size: CGSize) -> some View {
        VStack(spacing: 2) {
            Text(entry.date, style: .time)
                .font(clockFont)
                .foregroundStyle(skin.clockColor)

            Text(entry.date, style: .date)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(skin.clockColor.opacity(0.7))
        }
        .position(
            x: size.width * skin.clock.position.x,
            y: size.height * skin.clock.position.y
        )
    }

    // MARK: - Helpers

    private var clockFont: Font {
        if let fontName = skin.clock.font,
           UIFont(name: fontName, size: 12) != nil {
            return .custom(fontName, size: 32)
        }
        return .system(size: 32, weight: .bold, design: .monospaced)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func loadImage(named name: String, in directory: String) -> UIImage? {
        let baseName = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        if let url = Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "Skins/\(directory)") {
            return UIImage(contentsOfFile: url.path)
        }
        if let bundlePath = Bundle.main.resourcePath {
            let path = "\(bundlePath)/Skins/\(directory)/\(name)"
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }
}
