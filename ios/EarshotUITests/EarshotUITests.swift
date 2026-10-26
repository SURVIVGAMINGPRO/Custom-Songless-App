import XCTest

/// Plays a round the way a player would, against the real Deezer: load the
/// Top Worldwide chart, play a clip, pick and guess with Return, skip with a
/// double Return, finish the round, then look at Stats and Settings.
/// Screenshots are kept in the test results. Start from a fresh install.
@MainActor
final class EarshotUITests: XCTestCase {
	private let app = XCUIApplication()

	func testPlayARound() throws {
		continueAfterFailure = false
		app.launch()

		let sample = app.buttons["Try Deezer's Top Worldwide"]
		XCTAssertTrue(sample.waitForExistence(timeout: 10), "Start with a fresh install: the library should be empty")
		snap("1 Empty library")
		sample.tap()

		// The first game shows How to Play.
		XCTAssertTrue(app.navigationBars["How to Play"].waitForExistence(timeout: 30))
		snap("2 How to play")
		app.buttons["Done"].tap()

		let play = app.buttons["Play 0.1 seconds"].firstMatch
		XCTAssertTrue(play.waitForExistence(timeout: 10))
		snap("3 Play screen")
		play.tap()
		sleep(1)

		// Return picks the highlighted song, a second Return guesses it.
		let search = app.textFields["Search this playlist for your guess"]
		search.tap()
		search.typeText("a")
		sleep(1)
		snap("4 Suggestions")
		search.typeText("\n")
		sleep(1)
		snap("5 Picked")
		XCTAssertTrue(app.buttons["Guess"].exists || app.buttons["Guessed"].exists)
		// The guess, then at once the habitual extra Return: that one does nothing.
		search.typeText("\n\n")
		XCTAssertFalse(app.staticTexts["Press Return again to skip"].exists)
		sleep(1)
		snap("6 Guessed")
		XCTAssertTrue(app.buttons["Play 0.5 seconds"].firstMatch.exists || app.buttons["Play the preview"].exists)

		// Later, an empty Return skips only on the second press.
		search.typeText("\n")
		if app.buttons["Play 0.5 seconds"].firstMatch.exists {
			XCTAssertTrue(app.staticTexts["Press Return again to skip"].waitForExistence(timeout: 2))
			snap("7 Skip armed")
			search.typeText("\n")
			XCTAssertTrue(app.buttons["Play 2 seconds"].firstMatch.waitForExistence(timeout: 3))
		}

		// Skip to the end of the round.
		let skip = app.buttons["Skip"]
		for _ in 0..<5 where skip.exists {
			skip.tap()
		}
		XCTAssertTrue(app.buttons["Play the preview"].waitForExistence(timeout: 5) || app.buttons["Stop"].exists)
		sleep(2)
		snap("8 Result")

		app.navigationBars.buttons.element(boundBy: 0).tap()
		XCTAssertTrue(app.staticTexts["Top Worldwide"].firstMatch.waitForExistence(timeout: 5))
		snap("9 Library")

		app.buttons["Stats"].tap()
		XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 5))
		sleep(1)
		snap("10 Stats")

		app.buttons["Settings"].tap()
		XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
		snap("11 Settings")
	}

	private func snap(_ name: String) {
		let shot = XCTAttachment(screenshot: app.screenshot())
		shot.name = name
		shot.lifetime = .keepAlways
		add(shot)
	}
}
