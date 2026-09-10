import XCTest

final class RustBlockUITests: XCTestCase {
    func testDragPlacesPieceAndRefillsTray() {
        let app = XCUIApplication()
        app.launchArguments = ["--game-preview", "--ui-test-reset"]
        app.launch()

        let piece = app.otherElements["piece_0"]
        let board = app.otherElements["game_board"]
        let moves = app.otherElements["moves_label"]
        XCTAssertTrue(piece.waitForExistence(timeout: 3))
        XCTAssertTrue(board.exists)
        XCTAssertEqual(moves.value as? String, "0")
        let originalPieceID = piece.value as? String
        let originalBoardFrame = board.frame
        let originalViewport = app.otherElements["viewport_debug"].value as? String

        let start = piece.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = app.otherElements["cell_2_1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 54))
        start.press(forDuration: 0.15, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.1)

        let debug = app.otherElements["drag_debug"].value as? String ?? "missing"
        XCTAssertEqual(moves.value as? String, "1", debug)
        XCTAssertNotEqual(app.otherElements["piece_0"].value as? String, originalPieceID)
        XCTAssertGreaterThan(app.otherElements.matching(NSPredicate(format: "value == %@", "occupied")).count, 0)
        XCTAssertEqual(board.frame.minY, originalBoardFrame.minY, accuracy: 1, "Tahta sürükleme sırasında dikey konum değiştirdi")
        XCTAssertEqual(app.otherElements["viewport_debug"].value as? String, originalViewport, "Oyun sahnesi sürükleme sonrasında kaydı")
    }

    func testShopPurchaseAndBlastJoker() {
        let app = XCUIApplication()
        app.launchArguments = ["--game-preview", "--ui-test-reset"]
        app.launch()

        app.buttons["shop_button"].tap()
        let buyBlast = app.buttons["buy_blast"]
        XCTAssertTrue(buyBlast.waitForExistence(timeout: 3))
        buyBlast.tap()
        app.buttons["shop_close"].tap()

        let blast = app.buttons["power_blast"]
        XCTAssertTrue(blast.waitForExistence(timeout: 2))
        XCTAssertEqual(blast.value as? String, "2")

        let piece = app.otherElements["piece_0"]
        let start = piece.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = app.otherElements["cell_2_1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 54))
        start.press(forDuration: 0.12, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.08)
        XCTAssertEqual(app.otherElements["moves_label"].value as? String, "1")

        let occupied = app.otherElements.matching(NSPredicate(format: "value == %@", "occupied"))
        let before = occupied.count
        XCTAssertGreaterThan(before, 0)
        blast.tap()
        occupied.firstMatch.tap()
        XCTAssertEqual(blast.value as? String, "1")
        XCTAssertLessThan(app.otherElements.matching(NSPredicate(format: "value == %@", "occupied")).count, before)
    }

    func testClearExplosionDoesNotResizeBoard() {
        let app = XCUIApplication()
        app.launchArguments = ["--line-test", "--ui-test-reset"]
        app.launch()
        let board = app.otherElements["game_board"]
        XCTAssertTrue(board.waitForExistence(timeout: 3))
        let originalFrame = board.frame
        let cell = app.otherElements["cell_0_7"]
        let drop = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 54))
        app.otherElements["piece_0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.15, thenDragTo: drop, withVelocity: .slow, thenHoldForDuration: 0.1)
        let debug = app.otherElements["drag_debug"].value as? String ?? "missing"
        XCTAssertEqual(app.otherElements["moves_label"].value as? String, "8", debug)
        capture(app, "09-real-line-clear")
        XCTAssertEqual(app.otherElements["cell_0_0"].value as? String, "empty")
        XCTAssertEqual(board.frame.minX, originalFrame.minX, accuracy: 1)
        XCTAssertEqual(board.frame.minY, originalFrame.minY, accuracy: 1)
        XCTAssertEqual(board.frame.width, originalFrame.width, accuracy: 1)
        XCTAssertEqual(board.frame.height, originalFrame.height, accuracy: 1)
    }

    func testSavedGameSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--line-test", "--ui-test-reset"]
        app.launch()
        XCTAssertTrue(app.otherElements["game_board"].waitForExistence(timeout: 3))
        let originalPiece = app.otherElements["piece_0"].value as? String
        app.terminate()
        app.launchArguments = ["--ui-test"]
        app.launch()
        let resume = app.buttons["start_button"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        XCTAssertEqual(resume.label, "KALDIĞIN YERDEN DEVAM")
        resume.tap()
        XCTAssertEqual(app.otherElements["moves_label"].value as? String, "7")
        XCTAssertEqual(app.otherElements["piece_0"].value as? String, originalPiece)
        XCTAssertEqual(app.otherElements["cell_0_0"].value as? String, "occupied")
    }

    func testSettingsAndPageSnapshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()
        XCTAssertTrue(app.buttons["settings_button"].waitForExistence(timeout: 3))
        capture(app, "01-menu")
        app.buttons["settings_button"].tap()
        let sound = app.switches["sound_toggle"]
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
        sound.tap()
        XCTAssertEqual(sound.value as? String, "0")
        capture(app, "02-settings")
        app.buttons["Tamam"].tap()
        app.buttons["settings_button"].tap()
        XCTAssertEqual(sound.value as? String, "0")
        for (name, argument) in [("03-store", "--store-preview"), ("04-pause", "--pause-preview"), ("05-game-over", "--game-over-preview"), ("06-game", "--game-preview")] {
            app.terminate(); app.launchArguments = ["--ui-test", argument]; app.launch()
            switch argument {
            case "--store-preview": XCTAssertTrue(app.buttons["buy_blast"].waitForExistence(timeout: 10))
            case "--pause-preview": XCTAssertTrue(app.staticTexts["ATÖLYE DURDU"].waitForExistence(timeout: 10))
            case "--game-over-preview": XCTAssertTrue(app.staticTexts["ATÖLYE PAYDOSU"].waitForExistence(timeout: 10))
            default: XCTAssertTrue(app.otherElements["game_board"].waitForExistence(timeout: 10))
            }
            capture(app, name)
        }
        if app.frame.width > 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
            wait(for: [rotated], timeout: 5)
            Thread.sleep(forTimeInterval: 1)
            let board = app.otherElements["game_board"]
            XCTAssertTrue(board.waitForExistence(timeout: 3))
            XCTAssertTrue(app.frame.contains(board.frame))
            XCTAssertTrue(app.frame.contains(app.otherElements["piece_2"].frame))
            capture(app, "07-tablet-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testRescueSurvivesShopAndFinishedRunIsNotRestored() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--rescue-test"]
        app.launch()
        XCTAssertTrue(app.buttons["TURU BİTİR"].waitForExistence(timeout: 5))
        app.buttons["BLOK BOMBASI • 1"].tap()
        app.buttons["shop_button"].tap()
        XCTAssertTrue(app.buttons["shop_close"].waitForExistence(timeout: 5))
        app.buttons["shop_close"].tap()
        XCTAssertTrue(app.buttons["TURU BİTİR"].waitForExistence(timeout: 3))
        capture(app, "08-rescue")
        app.buttons["TURU BİTİR"].tap()
        app.buttons["ANA MENÜ"].tap()
        app.terminate(); app.launchArguments = ["--ui-test"]; app.launch()
        XCTAssertEqual(app.buttons["start_button"].label, "ATÖLYEYİ ÇALIŞTIR")
    }
}
