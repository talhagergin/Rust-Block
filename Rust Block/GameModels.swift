import Foundation
import CoreGraphics

enum GameBalance {
    static let boardSize = 8, startingLife = 8, rustArmor = 4
    static let pointsPerCell = 8, clearBonus = 120, comboBonus = 80, rustBreakBonus = 160
}

struct GridPoint: Hashable, Codable { let row: Int; let column: Int }

enum DragPlacementMapper {
    static let fingerLift: CGFloat = 54
    static func origin(for finger: CGPoint, in boardFrame: CGRect) -> GridPoint? {
        let point = CGPoint(x: finger.x, y: finger.y - fingerLift)
        let playable = boardFrame.insetBy(dx: 9, dy: 9)
        guard playable.contains(point), playable.width > 0, playable.height > 0 else { return nil }
        let column = min(7, max(0, Int((point.x - playable.minX) / (playable.width / 8))))
        let row = min(7, max(0, Int((point.y - playable.minY) / (playable.height / 8))))
        return .init(row: row, column: column)
    }
}
enum CellState: Equatable, Codable { case empty, active(life: Int, colorIndex: Int), rusted(armor: Int) }
struct Cell: Identifiable, Equatable, Codable {
    let point: GridPoint; var state: CellState = .empty
    var id: String { "\(point.row)-\(point.column)" }
}
struct Piece: Identifiable, Equatable, Codable { var id = UUID(); let points: [GridPoint]; let colorIndex: Int }
enum GamePhase: Equatable { case menu, playing, paused, gameOver }
struct RunStats: Codable { var linesCleared = 0; var rustCreated = 0; var rustBroken = 0 }

enum PowerUp: String, CaseIterable, Identifiable, Codable {
    case rustSolvent, blast, rewind
    var id: String { rawValue }
    var title: String { switch self { case .rustSolvent: "PAS SÖKÜCÜ"; case .blast: "BLOK BOMBASI"; case .rewind: "ÖMÜR YAĞI" } }
    var shortTitle: String { switch self { case .rustSolvent: "PAS SÖK"; case .blast: "PATLAT"; case .rewind: "YENİLE" } }
    var detail: String { switch self { case .rustSolvent: "Paslı hücreyi tamamen temizler."; case .blast: "Seçilen bloğun 3×3 çevresini patlatır."; case .rewind: "Bloğun sayacını yeniden 8 yapar." } }
    var assetName: String { switch self { case .rustSolvent: "PowerRustSolvent"; case .blast: "PowerBlast"; case .rewind: "PowerRewind" } }
    var cost: Int { switch self { case .rustSolvent: 24; case .blast: 42; case .rewind: 18 } }
}

enum PieceGenerator {
    private static let shapes: [[GridPoint]] = [
        [.init(row: 0, column: 0)],
        [.init(row: 0, column: 0), .init(row: 0, column: 1)],
        [.init(row: 0, column: 0), .init(row: 1, column: 0)],
        [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2)],
        [.init(row: 0, column: 0), .init(row: 1, column: 0), .init(row: 2, column: 0)],
        [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 1, column: 0)],
        [.init(row: 0, column: 0), .init(row: 1, column: 0), .init(row: 1, column: 1)],
        [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 1, column: 0), .init(row: 1, column: 1)],
        [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2), .init(row: 1, column: 1)]
    ]
    static func hand(for cells: [Cell]) -> [Piece] {
        var choices = shapes.shuffled()
        if cells.filter({ $0.state == .empty }).count < 18 { choices.insert(shapes[0], at: 0) }
        return choices.prefix(3).enumerated().map { Piece(points: $0.element, colorIndex: Int.random(in: 0...3)) }
    }
    static func next(for cells: [Cell]) -> Piece {
        let empties = cells.filter { $0.state == .empty }.count
        let pool = empties < 18 ? Array(shapes.prefix(5)) : shapes
        return Piece(points: pool.randomElement() ?? shapes[0], colorIndex: Int.random(in: 0...3))
    }
}

struct GameEngine: Codable {
    private(set) var cells: [Cell] = (0..<64).map { Cell(point: .init(row: $0 / 8, column: $0 % 8)) }
    private(set) var score = 0; private(set) var moves = 0; private(set) var combo = 0
    private(set) var stats = RunStats(); private(set) var message = "PARÇAYI SÜRÜKLE"

    func canPlace(_ piece: Piece, at origin: GridPoint) -> Bool {
        piece.points.allSatisfy { o in
            let p = GridPoint(row: origin.row + o.row, column: origin.column + o.column)
            return (0..<8).contains(p.row) && (0..<8).contains(p.column) && state(at: p) == .empty
        }
    }
    func hasMove(for pieces: [Piece]) -> Bool { pieces.contains { piece in cells.contains { canPlace(piece, at: $0.point) } } }
    mutating func place(_ piece: Piece, at origin: GridPoint) -> Bool {
        guard canPlace(piece, at: origin) else { message = "Orası dolu"; return false }
        for o in piece.points { set(.active(life: GameBalance.startingLife, colorIndex: piece.colorIndex), at: .init(row: origin.row + o.row, column: origin.column + o.column)) }
        moves += 1; score += piece.points.count * GameBalance.pointsPerCell; resolveClears(); decay(); return true
    }

    mutating func usePowerUp(_ powerUp: PowerUp, at point: GridPoint) -> [GridPoint] {
        guard (0..<8).contains(point.row), (0..<8).contains(point.column) else { return [] }
        switch powerUp {
        case .rustSolvent:
            guard case .rusted = state(at: point) else { return [] }
            set(.empty, at: point); stats.rustBroken += 1; score += 80
            return [point]
        case .blast:
            guard state(at: point) != .empty else { return [] }
            let affected = (-1...1).flatMap { rowOffset in
                (-1...1).compactMap { columnOffset -> GridPoint? in
                    let target = GridPoint(row: point.row + rowOffset, column: point.column + columnOffset)
                    guard (0..<8).contains(target.row), (0..<8).contains(target.column), state(at: target) != .empty else { return nil }
                    return target
                }
            }
            for target in affected {
                if case .rusted = state(at: target) { stats.rustBroken += 1 }
                set(.empty, at: target)
            }
            score += affected.count * 24
            return affected
        case .rewind:
            guard case let .active(life, colorIndex) = state(at: point), life < GameBalance.startingLife else { return [] }
            set(.active(life: GameBalance.startingLife, colorIndex: colorIndex), at: point)
            return [point]
        }
    }
    private mutating func resolveClears() {
        let rows = (0..<8).filter { r in (0..<8).allSatisfy { if case .active = state(at: .init(row: r, column: $0)) { true } else { false } } }
        let columns = (0..<8).filter { c in (0..<8).allSatisfy { if case .active = state(at: .init(row: $0, column: c)) { true } else { false } } }
        let cleared = Set(rows.flatMap { r in (0..<8).map { GridPoint(row: r, column: $0) } } + columns.flatMap { c in (0..<8).map { GridPoint(row: $0, column: c) } })
        guard !cleared.isEmpty else { combo = 0; message = "PAS YAKLAŞIYOR"; return }
        let lines = rows.count + columns.count; stats.linesCleared += lines
        combo += 1
        score += lines * GameBalance.clearBonus + max(0, lines - 1) * GameBalance.comboBonus
        message = lines > 1 ? "DOUBLE CLEAR" : "TEMİZ ÇİZGİ"
        for point in cleared { set(.empty, at: point) }
        for point in Set(cleared.flatMap(neighbors(of:))) {
            if case let .rusted(armor) = state(at: point) {
                if armor <= 1 { set(.empty, at: point); stats.rustBroken += 1; score += GameBalance.rustBreakBonus; message = "RUST BREAK" }
                else { set(.rusted(armor: armor - 1), at: point) }
            }
        }
    }
    private mutating func decay() {
        for index in cells.indices where cells[index].state != .empty {
            if case let .active(life, colorIndex) = cells[index].state {
                if life <= 1 { cells[index].state = .rusted(armor: GameBalance.rustArmor); stats.rustCreated += 1 }
                else { cells[index].state = .active(life: life - 1, colorIndex: colorIndex) }
            }
        }
    }
    private func neighbors(of p: GridPoint) -> [GridPoint] { [(1,0),(-1,0),(0,1),(0,-1)].compactMap { dr, dc in let q = GridPoint(row: p.row + dr, column: p.column + dc); return (0..<8).contains(q.row) && (0..<8).contains(q.column) ? q : nil } }
    func state(at p: GridPoint) -> CellState { cells[p.row * 8 + p.column].state }
    private mutating func set(_ state: CellState, at p: GridPoint) { cells[p.row * 8 + p.column].state = state }
}
