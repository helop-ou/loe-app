import Foundation
import Testing
import UIKit
@testable import Loe

/// The brand promises readable text on any cover's wash: ink at 8.8:1 or better, and
/// secondary text on a washed card at 4.9:1 or better, in both themes.
struct LoeCoverWashTests {
    private typealias RGB = (red: Double, green: Double, blue: Double)

    /// A brand colour as the app draws it, so a change to the colour is held to
    /// the promise too.
    private static func rgb(_ colour: ColorResource, dark: Bool) -> RGB {
        let theme = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var (red, green, blue): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        UIColor(resource: colour).resolvedColor(with: theme).getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red, green, blue)
    }

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
        let ink = Self.rgb(.loeInk, dark: dark)
        for degree in 0..<360 {
            let wash = try #require(LoeCover.washRGB(hue: Double(degree) / 360, saturation: 1, dark: dark, surface: .page))
            #expect(contrast(ink, wash) >= 8.8, "hue \(degree)°")
        }
    }

    @Test(arguments: [false, true])
    func secondaryTextStaysReadableOnEveryCardWash(dark: Bool) throws {
        let secondary = Self.rgb(.loeSecondary, dark: dark)
        for degree in 0..<360 {
            let wash = try #require(LoeCover.washRGB(hue: Double(degree) / 360, saturation: 1, dark: dark, surface: .card))
            #expect(contrast(secondary, wash) >= 4.9, "hue \(degree)°")
        }
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
