//  Sinu toon (your tone): the accent may lean towards the colours of the covers a reader
//  keeps. Only the accent moves. Every tone has the same weight as Eha, so contrast never
//  changes. Values come from loe-app-branding's src/tokens.mjs.

import CoreGraphics
import Foundation
import SwiftUI

nonisolated enum LoeTone: String, CaseIterable, Sendable {
    case eha, pohl, kanarbik, sirel, meri, laugas, sammal, mesi

    /// The tone used until a shelf clearly leans somewhere.
    static let standard = LoeTone.eha

    /// Name of the colour set in the asset catalog (light and dark values).
    var assetName: String {
        "LoeTone" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var color: Color { Color(assetName) }

    /// Hue of the tone, 0–1, in the same HSB space as `Sample.hue`.
    var hue: Double {
        switch self {
        case .eha: 0.0441
        case .pohl: 0.993
        case .kanarbik: 0.9137
        case .sirel: 0.7479
        case .meri: 0.5846
        case .laugas: 0.5134
        case .sammal: 0.347
        case .mesi: 0.1196
        }
    }

    /// Display names, for a settings row that lets the reader pick a tone by hand.
    var estonianName: String {
        switch self {
        case .eha: "Eha"
        case .pohl: "Pohl"
        case .kanarbik: "Kanarbik"
        case .sirel: "Sirel"
        case .meri: "Meri"
        case .laugas: "Laugas"
        case .sammal: "Sammal"
        case .mesi: "Mesi"
        }
    }

    var englishName: String {
        switch self {
        case .eha: "Afterglow"
        case .pohl: "Lingonberry"
        case .kanarbik: "Heather"
        case .sirel: "Lilac"
        case .meri: "Sea"
        case .laugas: "Bog pool"
        case .sammal: "Moss"
        case .mesi: "Honey"
        }
    }

    /// One cover's contribution to the tone.
    struct Sample: Sendable, Equatable {
        /// 0–1.
        var hue: Double
        /// 0–1. Grey and white covers count for little.
        var saturation: Double
        /// How much this book counts: the reader's rating, or 1.
        var weight: Double

        init(hue: Double, saturation: Double, weight: Double = 1) {
            self.hue = hue
            self.saturation = saturation
            self.weight = weight
        }
    }

    /// The tone a set of covers leans towards.
    /// Returns `standard` when there are too few covers, when they are mostly grey,
    /// or when their colours do not agree.
    static func leaning(
        of samples: [Sample],
        minimumCovers: Int = 5,
        minimumAgreement: Double = 0.35
    ) -> LoeTone {
        guard samples.count >= minimumCovers else { return standard }
        var x = 0.0
        var y = 0.0
        var coloured = 0.0
        var total = 0.0
        for sample in samples {
            let pull = sample.weight * sample.saturation
            x += pull * cos(2 * .pi * sample.hue)
            y += pull * sin(2 * .pi * sample.hue)
            coloured += pull
            total += sample.weight
        }
        // Mostly grey shelves have no tone to lean towards.
        guard total > 0, coloured / total >= 0.12 else { return standard }
        // 0 when hues are spread evenly round the wheel, 1 when they are all the same.
        let agreement = (x * x + y * y).squareRoot() / coloured
        guard agreement >= minimumAgreement else { return standard }
        var mean = atan2(y, x) / (2 * .pi)
        if mean < 0 { mean += 1 }
        func distance(_ a: Double, _ b: Double) -> Double {
            let d = abs(a - b)
            return min(d, 1 - d)
        }
        return allCases.min { distance($0.hue, mean) < distance($1.hue, mean) } ?? standard
    }

    /// A cover's average colour as a sample. Nil if the image cannot be read.
    /// The average is a rough reading of a cover, and enough to tell a shelf of reds
    /// from a shelf of blues.
    static func sample(from cover: CGImage, weight: Double = 1) -> Sample? {
        guard let rgb = LoeCover.averageRGB(of: cover) else { return nil }
        let high = max(rgb.red, rgb.green, rgb.blue)
        let low = min(rgb.red, rgb.green, rgb.blue)
        let spread = high - low
        guard high > 0, spread > 0 else { return Sample(hue: 0, saturation: 0, weight: weight) }
        var hue: Double
        if high == rgb.red {
            hue = ((rgb.green - rgb.blue) / spread).truncatingRemainder(dividingBy: 6)
        } else if high == rgb.green {
            hue = (rgb.blue - rgb.red) / spread + 2
        } else {
            hue = (rgb.red - rgb.green) / spread + 4
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return Sample(hue: hue, saturation: spread / high, weight: weight)
    }
}
