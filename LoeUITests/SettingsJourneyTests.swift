import XCTest

/// Settings and About on an in-memory library: the appearance, the quiz again,
/// iCloud, the catalogue, privacy and a credit with its licence.
final class SettingsJourneyTests: JourneyTestCase {
    @MainActor
    func testSettingsAndAbout() {
        let app = launch()
        app.buttons["Settings"].tap()

        let quizAgain = app.buttons["Take the quiz again"]
        XCTAssertTrue(quizAgain.waitForExistence(timeout: 5))
        quizAgain.tap()
        XCTAssertTrue(app.staticTexts["What do you like to read?"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
        XCTAssertTrue(quizAgain.waitForExistence(timeout: 5))

        // The appearance is kept on the simulator, so the journey starts and ends on the phone's own.
        let phone = app.buttons["Same as the phone"]
        scroll(app, to: phone)
        phone.tap()
        XCTAssertLessThan(Self.darkness(of: app), 0.5)
        app.buttons["Dark"].tap()
        XCTAssertTrue(app.buttons["Dark"].isSelected)
        XCTAssertGreaterThan(Self.darkness(of: app), 0.5)
        attach("settings-dark", app)
        phone.tap()
        XCTAssertTrue(phone.isSelected)
        XCTAssertLessThan(Self.darkness(of: app), 0.5)

        scroll(app, to: app.staticTexts["iCloud"])
        let statuses = NSPredicate(format: "label BEGINSWITH 'Your shelves sync' OR label BEGINSWITH 'iCloud is' OR label BEGINSWITH 'iCloud isn'")
        XCTAssertTrue(app.staticTexts.matching(statuses).firstMatch.waitForExistence(timeout: 10))

        // Loe fetches the catalogue by itself, so there is no removing it.
        scroll(app, to: app.buttons["About Loe"])
        XCTAssertTrue(app.staticTexts["Edition"].exists)
        XCTAssertTrue(app.buttons["Check for a new edition"].exists)
        XCTAssertFalse(app.buttons["Remove from this phone"].exists)
        attach("settings-catalogue", app)

        app.buttons["About Loe"].tap()
        let version = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Version '")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        attach("about", app)

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Privacy'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["What Loe sends, and where"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Newsreader'")).firstMatch.tap()
        let licence = app.staticTexts["SIL Open Font License 1.1"]
        XCTAssertTrue(licence.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PREAMBLE"].exists)
        attach("credit-newsreader", app)
        app.navigationBars.buttons.firstMatch.tap()

        // The catalogue's credit meets both licences it is published under.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'National Library of Estonia'")).firstMatch.tap()
        XCTAssertTrue(app.links["CC BY-SA 3.0 EE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CC0 1.0 Universal"].exists)
        attach("credit-national-library", app)
        app.navigationBars.buttons.firstMatch.tap()

        scroll(app, to: app.links["See the code on GitHub"])
        XCTAssertTrue(app.links["Report a problem on GitHub"].exists)
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    /// How dark the screen is, from 0 for white to 1 for black, to tell the themes apart.
    @MainActor
    private static func darkness(of app: XCUIApplication) -> Double {
        let image = app.screenshot().image
        guard let cgImage = image.cgImage else { return 0 }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        let total = pixels.enumerated().reduce(0.0) { sum, item in item.offset % 4 == 3 ? sum : sum + Double(item.element) }
        let brightness = total / Double(side * side * 3 * 255)
        return 1 - brightness
    }
}
