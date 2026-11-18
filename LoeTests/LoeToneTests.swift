import CoreGraphics
import Testing
@testable import Loe

struct LoeToneTests {
    private func shelf(hue: Double, count: Int = 6, saturation: Double = 0.8, weight: Double = 1) -> [LoeTone.Sample] {
        Array(repeating: LoeTone.Sample(hue: hue, saturation: saturation, weight: weight), count: count)
    }

    @Test func aSmallShelfStaysOnEha() {
        #expect(LoeTone.leaning(of: shelf(hue: 0.6, count: 4)) == .eha)
    }

    @Test func aGreyShelfStaysOnEha() {
        #expect(LoeTone.leaning(of: shelf(hue: 0.6, count: 10, saturation: 0.05)) == .eha)
    }

    @Test func coloursThatDisagreeStayOnEha() {
        let spread = (0..<8).map { LoeTone.Sample(hue: Double($0) / 8, saturation: 0.9) }
        #expect(LoeTone.leaning(of: spread) == .eha)
    }

    @Test(arguments: [
        (0.99, LoeTone.pohl),
        (0.6, .meri),
        (0.35, .sammal),
        (0.75, .sirel),
    ])
    func aShelfLeansTowardsItsColour(hue: Double, tone: LoeTone) {
        #expect(LoeTone.leaning(of: shelf(hue: hue)) == tone)
    }

    @Test func higherRatedCoversPullHarder() {
        let samples = shelf(hue: 0.6, count: 5, weight: 1) + shelf(hue: 0.35, count: 5, weight: 5)
        #expect(LoeTone.leaning(of: samples) == .sammal)
    }

    @Test func aRedCoverSamplesAsRed() throws {
        let sample = try #require(LoeTone.sample(from: solidImage(red: 0.8, green: 0.1, blue: 0.1)))
        #expect(abs(sample.hue) < 0.01)
        #expect(sample.saturation > 0.8)
    }

    @Test func aGreyCoverSamplesWithoutColour() throws {
        let sample = try #require(LoeTone.sample(from: solidImage(red: 0.5, green: 0.5, blue: 0.5)))
        #expect(sample.saturation == 0)
    }
}

func solidImage(red: Double, green: Double, blue: Double, size: Int = 8) -> CGImage {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}
