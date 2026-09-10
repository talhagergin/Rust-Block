import SwiftUI
import Combine

struct PlacementEvent: Identifiable { let id = UUID(); let origin: GridPoint; let points: [GridPoint] }
struct PowerEvent: Identifiable { let id = UUID(); let powerUp: PowerUp; let origin: GridPoint; let affected: [GridPoint] }

@MainActor final class GameViewModel: ObservableObject {
    @Published var phase: GamePhase = .menu; @Published var engine = GameEngine(); @Published var hand: [Piece] = []
    @Published var invalidCell: GridPoint?; @Published var burstID: UUID?; @Published var rustEventID: UUID?
    @Published var placementEvent: PlacementEvent?; @Published var powerEvent: PowerEvent?; @Published var coinEventID: UUID?
    @Published var selectedPowerUp: PowerUp?; @Published var isShopOpen = false
    @Published var hasSavedRun = false
    @Published var needsRescue = false
    @AppStorage("rust8.bestScore", store: GameStorage.defaults) var bestScore = 0
    @AppStorage("rust8.coins", store: GameStorage.defaults) var coins = 80
    @AppStorage("rust8.power.rustSolvent", store: GameStorage.defaults) private var rustSolventCount = 1
    @AppStorage("rust8.power.blast", store: GameStorage.defaults) private var blastCount = 1
    @AppStorage("rust8.power.rewind", store: GameStorage.defaults) private var rewindCount = 1

    init() { hasSavedRun = savedRun != nil }
    private var savedRun: SavedRun? {
        guard let data = GameStorage.defaults.data(forKey: "rust8.run"),
              let run = try? JSONDecoder().decode(SavedRun.self, from: data), run.isValid else { return nil }
        return run
    }
    func save() {
        guard !hand.isEmpty, phase == .playing || phase == .paused else { return }
        if let data = try? JSONEncoder().encode(SavedRun(version: 1, engine: engine, hand: hand)) {
            GameStorage.defaults.set(data, forKey: "rust8.run"); hasSavedRun = true
        }
    }
    func resume() {
        guard let run = savedRun else { start(); return }
        engine = run.engine; hand = run.hand; selectedPowerUp = nil; phase = .playing; evaluateMoves()
    }
    private func evaluateMoves() { needsRescue = !engine.hasMove(for: hand) }

    func start() {
        burstID = nil; rustEventID = nil; placementEvent = nil; powerEvent = nil; coinEventID = nil; invalidCell = nil; needsRescue = false
        engine = GameEngine(); hand = PieceGenerator.hand(for: engine.cells); selectedPowerUp = nil; phase = .playing
        save()
        GameAudio.shared.play(.start); GameAudio.shared.setMusicActive(true); Haptics.medium()
    }

    func place(_ piece: Piece, at point: GridPoint) {
        guard phase == .playing, !isShopOpen, hand.contains(where: { $0.id == piece.id }) else { return }
        let previousScore = engine.score
        let previousLines = engine.stats.linesCleared
        let previousRust = engine.stats.rustCreated
        guard engine.place(piece, at: point) else { invalidCell = point; GameAudio.shared.play(.invalid); Haptics.error(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.invalidCell = nil }; return }
        placementEvent = PlacementEvent(origin: point, points: piece.points)
        let placementID = placementEvent?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) { if self.placementEvent?.id == placementID { self.placementEvent = nil } }
        if engine.stats.rustCreated > previousRust {
            rustEventID = UUID(); GameAudio.shared.play(.rust); Haptics.rust()
            let eventID = rustEventID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) { if self.rustEventID == eventID { self.rustEventID = nil } }
        }
        if engine.stats.linesCleared > previousLines {
            burstID = UUID(); GameAudio.shared.play(.clear); Haptics.success()
            let eventID = burstID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.12) { if self.burstID == eventID { self.burstID = nil } }
        } else if engine.stats.rustCreated == previousRust { GameAudio.shared.play(.place) }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            if let index = hand.firstIndex(where: { $0.id == piece.id }) { hand[index] = PieceGenerator.next(for: engine.cells) }
        }
        Haptics.medium()
        awardCoins(since: previousScore)
        bestScore = max(bestScore, engine.score)
        evaluateMoves(); save()
    }

    func inventory(for powerUp: PowerUp) -> Int {
        switch powerUp { case .rustSolvent: rustSolventCount; case .blast: blastCount; case .rewind: rewindCount }
    }

    func select(_ powerUp: PowerUp) {
        guard phase == .playing, !isShopOpen else { return }
        if powerUp == .rustSolvent && !engine.cells.contains(where: { if case .rusted = $0.state { return true }; return false }) { GameAudio.shared.play(.invalid); return }
        guard inventory(for: powerUp) > 0 else { isShopOpen = true; GameAudio.shared.play(.invalid); return }
        selectedPowerUp = selectedPowerUp == powerUp ? nil : powerUp
        if selectedPowerUp != nil { needsRescue = false } else { evaluateMoves() }
        GameAudio.shared.play(.uiTap); Haptics.light()
    }

    func useSelectedPowerUp(at point: GridPoint) {
        guard phase == .playing, !isShopOpen, let powerUp = selectedPowerUp, inventory(for: powerUp) > 0 else { return }
        let previousScore = engine.score
        let affected = engine.usePowerUp(powerUp, at: point)
        guard !affected.isEmpty else {
            invalidCell = point; GameAudio.shared.play(.invalid); Haptics.error()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.invalidCell = nil }
            return
        }
        changeInventory(powerUp, by: -1)
        selectedPowerUp = nil
        powerEvent = PowerEvent(powerUp: powerUp, origin: point, affected: affected)
        let eventID = powerEvent?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { if self.powerEvent?.id == eventID { self.powerEvent = nil } }
        switch powerUp {
        case .rustSolvent: GameAudio.shared.play(.powerUp); Haptics.success()
        case .blast: GameAudio.shared.play(.blast); Haptics.rust()
        case .rewind: GameAudio.shared.play(.powerUp); Haptics.success()
        }
        awardCoins(since: previousScore)
        bestScore = max(bestScore, engine.score)
        evaluateMoves(); save()
    }

    func buy(_ powerUp: PowerUp) {
        guard coins >= powerUp.cost else { GameAudio.shared.play(.invalid); Haptics.error(); return }
        objectWillChange.send(); coins -= powerUp.cost; changeInventory(powerUp, by: 1)
        GameAudio.shared.play(.coin); Haptics.success()
    }

    func openShop() { selectedPowerUp = nil; isShopOpen = true; GameAudio.shared.play(.uiTap) }
    func closeShop() {
        isShopOpen = false
        if phase == .playing { evaluateMoves() }
        GameAudio.shared.play(.uiTap)
    }

    #if DEBUG
    func prepareRescueTest() {
        start()
        let piece = Piece(points: [.init(row: 0, column: 0)], colorIndex: 0)
        for index in 0..<64 {
            let position = index * 17 % 64
            _ = engine.place(piece, at: .init(row: position / 8, column: position % 8))
        }
        hand = (0..<3).map { Piece(points: [.init(row: 0, column: 0)], colorIndex: $0) }
        evaluateMoves(); save()
    }
    func prepareLineTest() {
        start()
        let piece = Piece(points: [.init(row: 0, column: 0)], colorIndex: 0)
        for column in 0..<7 { _ = engine.place(piece, at: .init(row: 0, column: column)) }
        hand = (0..<3).map { Piece(points: [.init(row: 0, column: 0)], colorIndex: $0) }
        save()
    }
    func resetEconomyForUITest() {
        objectWillChange.send(); coins = 80; rustSolventCount = 1; blastCount = 1; rewindCount = 1; isShopOpen = false
    }
    #endif

    private func changeInventory(_ powerUp: PowerUp, by amount: Int) {
        objectWillChange.send()
        switch powerUp {
        case .rustSolvent: rustSolventCount = max(0, rustSolventCount + amount)
        case .blast: blastCount = max(0, blastCount + amount)
        case .rewind: rewindCount = max(0, rewindCount + amount)
        }
    }

    private func awardCoins(since previousScore: Int) {
        let reward = max(0, engine.score / 100 - previousScore / 100)
        guard reward > 0 else { return }
        objectWillChange.send(); coins += reward; coinEventID = UUID(); GameAudio.shared.play(.coin)
        let eventID = coinEventID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if self.coinEventID == eventID { self.coinEventID = nil } }
    }

    func endGame() {
        needsRescue = false; selectedPowerUp = nil; hasSavedRun = false
        GameStorage.defaults.removeObject(forKey: "rust8.run")
        phase = .gameOver; GameAudio.shared.setMusicActive(false); GameAudio.shared.play(.gameOver); Haptics.error()
    }
}
enum Haptics {
    private static var enabled: Bool { GameStorage.defaults.object(forKey: "rust8.haptics") as? Bool != false }
    static func light() { if enabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func medium() { if enabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
    static func error() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.error) } }
    static func success() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func rust() { if enabled { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1) } }
}
