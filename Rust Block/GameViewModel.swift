import SwiftUI
import Combine

struct PlacementEvent: Identifiable { let id = UUID(); let origin: GridPoint; let points: [GridPoint] }
struct PowerEvent: Identifiable { let id = UUID(); let powerUp: PowerUp; let origin: GridPoint; let affected: [GridPoint] }

@MainActor final class GameViewModel: ObservableObject {
    @Published var phase: GamePhase = .menu; @Published var engine = GameEngine(); @Published var hand: [Piece] = []
    @Published var invalidCell: GridPoint?; @Published var burstID: UUID?; @Published var rustEventID: UUID?
    @Published var placementEvent: PlacementEvent?; @Published var powerEvent: PowerEvent?; @Published var coinEventID: UUID?
    @Published var selectedPowerUp: PowerUp?; @Published var isShopOpen = false
    @AppStorage("rust8.bestScore") var bestScore = 0
    @AppStorage("rust8.coins") var coins = 80
    @AppStorage("rust8.power.rustSolvent") private var rustSolventCount = 1
    @AppStorage("rust8.power.blast") private var blastCount = 1
    @AppStorage("rust8.power.rewind") private var rewindCount = 1

    func start() {
        engine = GameEngine(); hand = PieceGenerator.hand(for: engine.cells); selectedPowerUp = nil; phase = .playing
        GameAudio.shared.play(.start); GameAudio.shared.setMusicActive(true); Haptics.medium()
    }

    func place(_ piece: Piece, at point: GridPoint) {
        let previousScore = engine.score
        let previousLines = engine.stats.linesCleared
        let previousRust = engine.stats.rustCreated
        guard engine.place(piece, at: point) else { invalidCell = point; GameAudio.shared.play(.invalid); Haptics.error(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.invalidCell = nil }; return }
        placementEvent = PlacementEvent(origin: point, points: piece.points)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) { self.placementEvent = nil }
        if engine.stats.rustCreated > previousRust {
            rustEventID = UUID(); GameAudio.shared.play(.rust); Haptics.rust()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) { self.rustEventID = nil }
        } else if engine.stats.linesCleared > previousLines {
            burstID = UUID(); GameAudio.shared.play(.clear); Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.12) { self.burstID = nil }
        } else { GameAudio.shared.play(.place) }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            if let index = hand.firstIndex(where: { $0.id == piece.id }) { hand[index] = PieceGenerator.next(for: engine.cells) }
        }
        Haptics.medium()
        awardCoins(since: previousScore)
        bestScore = max(bestScore, engine.score)
        if !engine.hasMove(for: hand) {
            if inventory(for: .blast) > 0 { selectedPowerUp = .blast }
            else { endGame() }
        }
    }

    func inventory(for powerUp: PowerUp) -> Int {
        switch powerUp { case .rustSolvent: rustSolventCount; case .blast: blastCount; case .rewind: rewindCount }
    }

    func select(_ powerUp: PowerUp) {
        guard inventory(for: powerUp) > 0 else { isShopOpen = true; GameAudio.shared.play(.invalid); return }
        selectedPowerUp = selectedPowerUp == powerUp ? nil : powerUp
        GameAudio.shared.play(.uiTap); Haptics.light()
    }

    func useSelectedPowerUp(at point: GridPoint) {
        guard let powerUp = selectedPowerUp else { return }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.powerEvent = nil }
        switch powerUp {
        case .rustSolvent: GameAudio.shared.play(.powerUp); Haptics.success()
        case .blast: GameAudio.shared.play(.blast); Haptics.rust()
        case .rewind: GameAudio.shared.play(.powerUp); Haptics.success()
        }
        awardCoins(since: previousScore)
        bestScore = max(bestScore, engine.score)
    }

    func buy(_ powerUp: PowerUp) {
        guard coins >= powerUp.cost else { GameAudio.shared.play(.invalid); Haptics.error(); return }
        objectWillChange.send(); coins -= powerUp.cost; changeInventory(powerUp, by: 1)
        GameAudio.shared.play(.coin); Haptics.success()
    }

    func openShop() { selectedPowerUp = nil; isShopOpen = true; GameAudio.shared.play(.uiTap) }
    func closeShop() { isShopOpen = false; GameAudio.shared.play(.uiTap) }

    func resetEconomyForUITest() {
        objectWillChange.send(); coins = 80; rustSolventCount = 1; blastCount = 1; rewindCount = 1; isShopOpen = false
    }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.coinEventID = nil }
    }

    private func endGame() {
        phase = .gameOver; GameAudio.shared.setMusicActive(false); GameAudio.shared.play(.gameOver); Haptics.error()
    }
}
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func rust() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1) }
}
