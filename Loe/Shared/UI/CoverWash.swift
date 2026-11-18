import SwiftUI

/// The soft wash of a cover's colour behind a book's page or the card for the
/// book being read. Grey covers get none.
enum CoverWash {
    static func color(_ sample: LoeTone.Sample, dark: Bool, surface: LoeCover.Surface) -> Color? {
        LoeCover.washRGB(hue: sample.hue, saturation: sample.saturation, dark: dark, surface: surface)
            .map { Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue) }
    }
}
