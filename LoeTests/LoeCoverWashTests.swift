import Foundation
import Testing
@testable import Loe

/// The brand promises readable text on any cover's wash: ink at 8.8:1 or better, and
/// secondary text on a washed card at 4.9:1 or better, in both themes.
struct LoeCoverWashTests {
    private typealias RGB = (red: Double, green: Double, blue: Double)

    private static let ink: [Bool: RGB] = [false: hex(0x2E1C2B), true: hex(0xF8EEDC)]
    private static let secondary: [Bool: RGB] = [false: hex(0x6F5C69), true: hex(0xBDAAB7)]

    @Test func aGreyCoverGetsNoWash() {
        #expect(LoeCover.washRGB(hue: 0.3, saturation: 0.03, dark: false, surface: .page) == nil)
    }

    @Test func aColourfulCoverTintsThePage() throws {
        let wash = try #require(LoeCover.washRGB(hue: 0.35, saturation: 0.8, dark: false, surface: .page))
        #expect(wash.green > wash.red)
        #expect(wash.green > wash.blue)
    }

    @Test(arguments: [false, true])
    func inkStaysReadableOnEveryPageWash(dark: Bool) throws {
        for degree in 0..<360 {
            let wash = try #require(LoeCover.washRGB(hue: Double(degree) / 360, saturation: 1, dark: dark, surface: .page))
            #expect(contrast(Self.ink[dark]!, wash) >= 8.8, "hue \(degree)°")
        }
    }

    @Test(arguments: [false, true])
    func secondaryTextStaysReadableOnEveryCardWash(dark: Bool) throws {
        for degree in 0..<360 {
            let wash = try #require(LoeCover.washRGB(hue: Double(degree) / 360, saturation: 1, dark: dark, surface: .card))
            #expect(contrast(Self.secondary[dark]!, wash) >= 4.9, "hue \(degree)°")
        }
    }

    private static func hex(_ value: Int) -> RGB {
        (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    private func contrast(_ a: RGB, _ b: RGB) -> Double {
        func luminance(_ c: RGB) -> Double {
            func linear(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
