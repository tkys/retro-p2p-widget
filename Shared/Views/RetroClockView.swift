import SwiftUI
import WidgetKit

struct RetroClockView: View {
    let entry: ClockEntry
    let skin: SkinDefinition

    init(entry: ClockEntry) {
        self.entry = entry
        self.skin = entry.skin
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background: image or solid color
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
        if let images = skin.images,
           let bgName = images.background,
           let bgImage = loadImage(named: bgName, in: images.directory) {
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

    // MARK: - Sprite Clock

    @ViewBuilder
    private func spriteClockLayer(images: SkinDefinition.SkinImages, in size: CGSize) -> some View {
        let timeStr = formatTime(entry.date)
        let digitW = images.digitWidth ?? 9
        let digitH = images.digitHeight ?? 13
        let scale = skin.clock.scale ?? max(size.height / 50, 2)

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

        // Try Skins/<directory>/<name>
        if let url = Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "Skins/\(directory)") {
            return UIImage(contentsOfFile: url.path)
        }
        // Try direct path construction
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
