import Foundation

enum GameStorage {
    static let defaults: UserDefaults = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-test-reset") || arguments.contains("--ui-test") {
            let suite = "rust8.ui-tests"
            let defaults = UserDefaults(suiteName: suite)!
            if arguments.contains("--ui-test-reset") { defaults.removePersistentDomain(forName: suite) }
            return defaults
        }
        #endif
        return .standard
    }()
}

struct SavedRun: Codable {
    let version: Int
    let engine: GameEngine
    let hand: [Piece]
    var isValid: Bool {
        version == 1 && engine.cells.count == 64 && hand.count == 3 &&
        engine.cells.enumerated().allSatisfy { $0.element.point == GridPoint(row: $0.offset / 8, column: $0.offset % 8) } &&
        hand.allSatisfy { !$0.points.isEmpty && $0.points.count <= 4 && (0...3).contains($0.colorIndex) && $0.points.allSatisfy { (0..<4).contains($0.row) && (0..<4).contains($0.column) } }
    }
}
