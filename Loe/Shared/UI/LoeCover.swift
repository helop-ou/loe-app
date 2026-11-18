import CoreImage
import SwiftUI

/// Colour taken from a book's cover.
nonisolated enum LoeCover {
    // Creating a context is expensive, and a shelf samples every cover.
    private static let context = CIContext()

    /// Where the wash is drawn. Text may sit on a card wash; a page wash sits behind the cover.
    enum Surface: Sendable {
        case page
        case card
    }

    /// The wash for a cover: its hue, rebuilt at a fixed brightness and blended into the
    /// surface, so any cover gives a readable result by day and by night.
    /// Nil for covers with no clear colour (grey, white, black): draw no wash for those.
    ///
    ///     LinearGradient(colors: [wash, .loeBackground], startPoint: .top, endPoint: .bottom)
    ///
    /// On a wash, set text in `loeInk`. Keep the accent for icons and filled buttons.
    static func wash(from cover: CGImage, scheme: ColorScheme, on surface: Surface = .page) -> Color? {
        guard
            let sample = LoeTone.sample(from: cover),
            let rgb = washRGB(hue: sample.hue, saturation: sample.saturation, dark: scheme == .dark, surface: surface)
        else { return nil }
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    static func washRGB(
        hue: Double,
        saturation: Double,
        dark: Bool,
        surface: Surface
    ) -> (red: Double, green: Double, blue: Double)? {
        guard saturation >= 0.06 else { return nil }
        // Greyer covers get less of the tint; a cover at 0.35 saturation or more gets all of it.
        let share = min(1, saturation / 0.35)
        let brightness = dark ? 0.32 : 0.93
        let tintSaturation = (dark ? 0.5 : 0.26) * share
        let strength: Double
        let base: (Double, Double, Double)
        switch (surface, dark) {
        case (.page, false): strength = 0.6; base = (0.9882, 0.9686, 0.9333)
        case (.page, true): strength = 0.75; base = (0.1098, 0.0824, 0.1059)
        case (.card, false): strength = 0.3; base = (1.0000, 0.9922, 0.9765)
        case (.card, true): strength = 0.4; base = (0.1647, 0.1255, 0.1608)
        }
        func channel(_ n: Double) -> Double {
            let k = (n + hue * 6).truncatingRemainder(dividingBy: 6)
            return brightness - brightness * tintSaturation * max(0, min(k, 4 - k, 1))
        }
        let tint = (channel(5), channel(3), channel(1))
        return (
            base.0 + (tint.0 - base.0) * strength,
            base.1 + (tint.1 - base.1) * strength,
            base.2 + (tint.2 - base.2) * strength
        )
    }

    static func averageRGB(of cover: CGImage) -> (red: Double, green: Double, blue: Double)? {
        let image = CIImage(cgImage: cover)
        guard
            let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: image.extent)]
            ),
            let output = filter.outputImage,
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: sRGB
        )
        return (Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255)
    }
}
