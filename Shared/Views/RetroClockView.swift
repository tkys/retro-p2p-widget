import SwiftUI
import WidgetKit

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
                // Background: size-specific image or fallback
                backgroundLayer(in: geo.size)

                // Decorations layer
                ForEach(Array(skin.decorations.enumerated()), id: \.offset) { _, decoration in
                    decorationView(decoration, in: geo.size)
                }

                // Clock display
                if skin.clock.style == "sprite", let images = skin.images {
                    spriteClockLayer(images: images, in: geo.size)
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

        // Try size-specific background first
        let sizedName: String? = switch family {
        case .systemSmall:  images.backgroundSmall ?? "bg-small.png"
        case .systemMedium: images.backgroundMedium ?? "bg-medium.png"
        case .systemLarge:  images.backgroundLarge ?? "bg-large.png"
        default:            images.background
        }

        if let name = sizedName, let img = loadImage(named: name, in: images.directory) {
            return img
        }
        // Fall back to generic background
        if let bg = images.background {
            return loadImage(named: bg, in: images.directory)
        }
        return nil
    }

    // MARK: - Sprite Clock

    @ViewBuilder
    private func spriteClockLayer(images: SkinDefinition.SkinImages, in size: CGSize) -> some View {
        let timeStr = formatTime(entry.date)
        let digitW = images.digitWidth ?? 9
        let digitH = images.digitHeight ?? 13
        let scale = skin.clock.scale ?? scaleForFamily(size: size)

        if let numbersName = images.numbers,
           let spriteSheet = loadImage(named: numbersName, in: images.directory) {
            SpriteNumberView(
                timeString: timeStr,
                spriteSheet: spriteSheet,
                digitWidth: digitW,
                digitHeight: digitH,
                scale: scale
            )
            .position(
                x: size.width * skin.clock.position.x,
                y: size.height * skin.clock.position.y
            )
        }
    }

    private func scaleForFamily(size: CGSize) -> CGFloat {
        switch family {
        case .systemSmall:  return max(size.height / 55, 2)
        case .systemMedium: return max(size.height / 45, 2.5)
        case .systemLarge:  return max(size.height / 80, 3)
        default:            return 2.5
        }
    }

    // MARK: - Text Clock (fallback)

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

    @ViewBuilder
    private func decorationView(_ decoration: SkinDefinition.Decoration, in size: CGSize) -> some View {
        let color = Color(hex: decoration.color)
        switch decoration.type {
        case "line":
            if let from = decoration.from, let to = decoration.to,
               from.count == 2, to.count == 2 {
                Path { path in
                    path.move(to: CGPoint(x: size.width * from[0], y: size.height * from[1]))
                    path.addLine(to: CGPoint(x: size.width * to[0], y: size.height * to[1]))
                }
                .stroke(color, lineWidth: 1)
            }
        case "text":
            if let text = decoration.text, let pos = decoration.position {
                Text(text)
                    .font(.system(size: decoration.fontSize ?? 10, design: .monospaced))
                    .foregroundStyle(color)
                    .position(x: size.width * pos.x, y: size.height * pos.y)
            }
        default:
            EmptyView()
        }
    }
}
