import SwiftUI
import UIKit

struct SpriteNumberView: View {
    let timeString: String
    let spriteSheet: UIImage
    let digitWidth: CGFloat
    let digitHeight: CGFloat
    let scale: CGFloat

    // Winamp numbers.bmp layout: digits 0-9 in a row, each digitWidth x digitHeight
    // Characters mapped: 0,1,2,3,4,5,6,7,8,9, then blank (index 10)
    // Some sheets also have colon-like chars but we draw colon separately

    var body: some View {
        HStack(spacing: scale * 1) {
            ForEach(Array(timeString.enumerated()), id: \.offset) { _, char in
                if char == ":" {
                    colonView
                } else if let digit = char.wholeNumberValue {
                    digitView(for: digit)
                }
            }
        }
    }

    private func digitView(for digit: Int) -> some View {
        let cropRect = CGRect(
            x: CGFloat(digit) * digitWidth,
            y: 0,
            width: digitWidth,
            height: digitHeight
        )
        return spriteDigit(rect: cropRect)
    }

    private var colonView: some View {
        // Draw a simple colon matching the sprite style
        VStack(spacing: scale * 3) {
            Circle()
                .fill(Color.white)
                .frame(width: scale * 2, height: scale * 2)
            Circle()
                .fill(Color.white)
                .frame(width: scale * 2, height: scale * 2)
        }
        .frame(width: scale * digitWidth * 0.4, height: scale * digitHeight)
    }

    private func spriteDigit(rect: CGRect) -> some View {
        let cropped = cropImage(spriteSheet, to: rect)
        return Image(uiImage: cropped)
            .interpolation(.none)
            .resizable()
            .frame(width: scale * digitWidth, height: scale * digitHeight)
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage {
        let scaleFactor = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scaleFactor,
            y: rect.origin.y * scaleFactor,
            width: rect.width * scaleFactor,
            height: rect.height * scaleFactor
        )
        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: scaledRect) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: scaleFactor, orientation: .up)
    }
}
