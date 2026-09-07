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
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.43))
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
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.43))
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
        app.launchArguments = ["--clear-preview", "--ui-test-reset"]
        app.launch()
        let board = app.otherElements["game_board"]
        XCTAssertTrue(board.waitForExistence(timeout: 3))
        let originalFrame = board.frame
        Thread.sleep(forTimeInterval: 1.35)
        XCTAssertEqual(board.frame.minX, originalFrame.minX, accuracy: 1)
        XCTAssertEqual(board.frame.minY, originalFrame.minY, accuracy: 1)
        XCTAssertEqual(board.frame.width, originalFrame.width, accuracy: 1)
        XCTAssertEqual(board.frame.height, originalFrame.height, accuracy: 1)
    }
}
