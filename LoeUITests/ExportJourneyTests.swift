import XCTest

/// Exporting the shelves from Settings: nothing to export while they are empty,
/// and with a book on them the system's share sheet is handed a CSV file named
/// for the day.
final class ExportJourneyTests: JourneyTestCase {
    @MainActor
    func testExportsTheShelvesAsAFile() {
        let app = launch()

        app.buttons["Settings"].tap()
        let export = app.buttons["Export my shelves"]
        scroll(app, to: export)
        XCTAssertFalse(export.isEnabled)
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("keisri hull")
        let result = app.staticTexts["Keisri hull"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let add = app.buttons["Add to shelf"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["Reading"].tap()
        XCTAssertTrue(app.buttons["Shelf: Reading"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Shelves"].tap()
        app.buttons["Settings"].tap()
        scroll(app, to: export)
        XCTAssertTrue(export.isEnabled)
        attach("export-settings", app)
        export.tap()

        // The share sheet names what it was handed.
        let file = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Loe 20' AND identifier ENDSWITH '.csv'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Save to Files"].waitForExistence(timeout: 5))
        attach("export-share-sheet", app)
    }

    @MainActor
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
