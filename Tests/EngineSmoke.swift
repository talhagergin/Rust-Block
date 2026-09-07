import Foundation

@main
enum EngineSmoke {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAILED: \(message)") }
    }

    static func main() {
        let single = Piece(points: [.init(row: 0, column: 0)], colorIndex: 2)
        var engine = GameEngine()
        expect(engine.place(single, at: .init(row: 0, column: 0)), "single tile should place")
        expect(engine.moves == 1, "move counter should increment")
        expect(engine.score == GameBalance.pointsPerCell, "cell score should be awarded")
        expect(engine.state(at: .init(row: 0, column: 0)) == .active(life: 7, colorIndex: 2), "new tile should decay to seven after move")
        expect(!engine.canPlace(single, at: .init(row: 0, column: 0)), "occupied tile should reject placement")

        var rowEngine = GameEngine()
        for column in 0..<8 { expect(rowEngine.place(single, at: .init(row: 0, column: column)), "row placement \(column)") }
        expect(rowEngine.stats.linesCleared == 1, "completed row should clear")
        expect((0..<8).allSatisfy { rowEngine.state(at: .init(row: 0, column: $0)) == .empty }, "cleared row should be empty")

        var rustEngine = GameEngine()
        let agingPoints = [GridPoint(row: 0, column: 0), .init(row: 1, column: 2), .init(row: 2, column: 4), .init(row: 3, column: 6), .init(row: 4, column: 1), .init(row: 5, column: 3), .init(row: 6, column: 5), .init(row: 7, column: 7)]
        for point in agingPoints { expect(rustEngine.place(single, at: point), "aging placement") }
        expect(rustEngine.state(at: .init(row: 0, column: 0)) == .rusted(armor: 4), "oldest tile should rust on eighth move")
        expect(rustEngine.stats.rustCreated == 1, "rust statistic should increment")
        expect(rustEngine.usePowerUp(.rewind, at: .init(row: 7, column: 7)) == [.init(row: 7, column: 7)], "rewind should target an active block")
        expect(rustEngine.state(at: .init(row: 7, column: 7)) == .active(life: 8, colorIndex: 2), "rewind should restore life to eight")
        expect(rustEngine.usePowerUp(.rustSolvent, at: .init(row: 0, column: 0)) == [.init(row: 0, column: 0)], "solvent should remove rust")
        expect(rustEngine.state(at: .init(row: 0, column: 0)) == .empty, "solvent target should become empty")

        var blastEngine = GameEngine()
        expect(blastEngine.place(single, at: .init(row: 4, column: 4)), "blast setup one")
        expect(blastEngine.place(single, at: .init(row: 4, column: 5)), "blast setup two")
        expect(blastEngine.usePowerUp(.blast, at: .init(row: 4, column: 4)).count == 2, "blast should clear occupied cells in a 3x3 area")
        expect(blastEngine.state(at: .init(row: 4, column: 4)) == .empty && blastEngine.state(at: .init(row: 4, column: 5)) == .empty, "blast area should be empty")

        let frame = CGRect(x: 20, y: 100, width: 320, height: 320)
        expect(DragPlacementMapper.origin(for: CGPoint(x: 49, y: 183), in: frame) == .init(row: 0, column: 0), "drag should map to first cell")
        expect(DragPlacementMapper.origin(for: CGPoint(x: 311, y: 443), in: frame) == .init(row: 7, column: 7), "drag should map to final cell")
        expect(DragPlacementMapper.origin(for: CGPoint(x: 10, y: 100), in: frame) == nil, "drag outside board should reject")

        print("EngineSmoke: placement, clear, decay, rust, power-ups, and drag mapping passed")
    }
}
