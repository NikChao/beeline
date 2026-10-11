import XCTest

/// Writing with the server away, in three acts. Each test is run on its own,
/// with the server up, then down, then up again:
///
///     xcodebuild test -only-testing:BeelineUITests/OfflineUITests/test1_keepPagesWhileOnline
///
final class OfflineUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    /// Links read as one label (title, author, excerpt), so match a part of it.
    private func text(containing part: String) -> XCUIElement {
        app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", part)).firstMatch
    }

    /// Server up: open the shelf and the desk so their pages are kept.
    func test1_keepPagesWhileOnline() {
        app.launch()
        XCTAssert(app.navigationBars["Shelf"].waitForExistence(timeout: 30))

        app.tabBars.buttons["Desk"].tap()
        XCTAssert(app.navigationBars["Desk"].waitForExistence(timeout: 15))
        sleep(4) // let the copies land
    }

    /// Server down: the kept pages open, and a published page waits in the outbox.
    func test2_writeWithoutTheServer() {
        app.launch()
        XCTAssert(app.navigationBars["Shelf"].waitForExistence(timeout: 30))

        app.navigationBars["Shelf"].buttons["New page"].tap()

        let title = app.webViews.textFields["Title"]
        XCTAssert(title.waitForExistence(timeout: 15))
        title.tap()
        title.typeText("Written without a server")

        let body = app.webViews.textViews["Body"]
        body.tap()
        body.typeText("Nothing to send it to, yet.")

        // The keyboard covers the page's buttons; put it away first.
        app.buttons["Done"].firstMatch.tap()
        XCTAssert(app.keyboards.element.waitForNonExistence(timeout: 5))
        app.webViews.buttons["Publish"].tap()

        // Optimistic: the writing closes, and the page is on the shelf, waiting.
        XCTAssert(app.navigationBars["Shelf"].waitForExistence(timeout: 15))
        XCTAssert(text(containing: "Written without a server").waitForExistence(timeout: 15))
        XCTAssert(text(containing: "waiting to sync").exists)
    }

    /// Server back: the app syncs the outbox as soon as a page loads.
    func test3_syncWhenTheServerIsBack() {
        app.launch()
        XCTAssert(app.navigationBars["Shelf"].waitForExistence(timeout: 30))

        // Synced, and the shelf fetched again: there for real, nothing waiting.
        XCTAssert(text(containing: "Written without a server").waitForExistence(timeout: 20))
        let waiting = text(containing: "waiting to sync")
        XCTAssert(waiting.waitForNonExistence(timeout: 20))
    }
}
