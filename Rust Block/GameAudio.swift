import AVFoundation

enum GameSound: String, CaseIterable {
    case place = "sfx_place"
    case invalid = "sfx_invalid"
    case clear = "sfx_clear"
    case rust = "sfx_rust"
    case gameOver = "sfx_game_over"
    case start = "sfx_start"
    case uiTap = "sfx_ui_tap"
    case powerUp = "sfx_power_up"
    case coin = "sfx_coin"
    case blast = "sfx_blast"
}

@MainActor
final class GameAudio {
    static let shared = GameAudio()

    private var players: [GameSound: [AVAudioPlayer]] = [:]
    private var nextPlayer: [GameSound: Int] = [:]
    private var musicPlayer: AVAudioPlayer?

    private init() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        for sound in GameSound.allCases {
            guard let url = soundURL(for: sound) else { continue }
            let poolSize = sound == .place ? 3 : 2
            players[sound] = (0..<poolSize).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.volume = volume(for: sound)
                player.prepareToPlay()
                return player
            }
        }
        if let musicURL = Bundle.main.url(forResource: "music_workshop", withExtension: "wav"), let music = try? AVAudioPlayer(contentsOf: musicURL) {
            music.numberOfLoops = -1; music.volume = 0.19; music.prepareToPlay(); musicPlayer = music
        }
    }

    func play(_ sound: GameSound) {
        guard let pool = players[sound], !pool.isEmpty else { return }
        let index = nextPlayer[sound, default: 0] % pool.count
        nextPlayer[sound] = index + 1
        let player = pool[index]
        player.currentTime = 0
        player.play()
    }

    func setMusicActive(_ active: Bool) {
        guard let musicPlayer else { return }
        if active {
            guard !musicPlayer.isPlaying else { return }
            if musicPlayer.currentTime >= musicPlayer.duration - 0.1 { musicPlayer.currentTime = 0 }
            musicPlayer.play()
        } else if musicPlayer.isPlaying { musicPlayer.pause() }
    }

    private func soundURL(for sound: GameSound) -> URL? {
        Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
    }

    private func volume(for sound: GameSound) -> Float {
        switch sound {
        case .place: 0.62
        case .uiTap: 0.52
        case .invalid: 0.72
        case .clear: 0.82
        case .rust: 0.86
        case .start: 0.72
        case .gameOver: 0.88
        case .powerUp: 0.8
        case .coin: 0.58
        case .blast: 0.9
        }
    }
}
