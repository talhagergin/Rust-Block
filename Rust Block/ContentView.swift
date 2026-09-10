import SwiftUI

struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            IndustrialBackground()
            switch model.phase {
            case .menu: MainMenuView(model: model).transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .playing, .paused: GameView(model: model).frame(maxWidth: 560).transition(.opacity)
            case .gameOver: GameOverView(model: model).transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
            if model.phase == .paused { PauseOverlay(model: model).zIndex(10) }
            if model.needsRescue && model.phase == .playing { RescueOverlay(model: model).zIndex(11) }
            if model.isShopOpen { StoreOverlay(model: model).transition(.opacity).zIndex(20) }
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: model.phase)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isShopOpen)
        .preferredColorScheme(.light)
        .onChange(of: model.phase) { _, phase in GameAudio.shared.setMusicActive(phase == .playing) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.save(); if model.phase == .playing { model.phase = .paused }; GameAudio.shared.setMusicActive(false) }
        }
        .onChange(of: model.isShopOpen) { _, open in GameAudio.shared.setMusicActive(!open && model.phase == .playing) }
        .onAppear {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--ui-test-reset") { model.resetEconomyForUITest() }
            if arguments.contains("--rescue-test") { model.prepareRescueTest() }
            else if arguments.contains("--line-test") { model.prepareLineTest() }
            else if arguments.contains("--store-preview") { model.isShopOpen = true }
            else if arguments.contains("--pause-preview") { model.start(); model.phase = .paused }
            else if arguments.contains("--game-over-preview") { model.phase = .gameOver }
            else if arguments.contains("--rust-preview") {
                model.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { model.rustEventID = UUID() }
            } else if arguments.contains("--clear-preview") {
                model.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { model.burstID = UUID() }
            } else if arguments.contains("--clear-visual") {
                model.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { model.burstID = UUID() }
            } else if arguments.contains("--game-preview") { model.start() }
            #endif
        }
    }
}

struct MainMenuView: View {
    @ObservedObject var model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    @State private var spin = false
    @State private var showSettings = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.05, green: 0.16, blue: 0.16).opacity(0.17).ignoresSafeArea()
                AmbientSparkField(color: .orange, count: 34)
                ScrollView { VStack(spacing: 14) {
                    HStack {
                        Label("ATÖLYE • 01", systemImage: "sparkle").font(.caption.weight(.black)).tracking(2)
                        Spacer()
                        Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44).background(.white.opacity(0.85), in: Circle()).brassBorder(radius: 22).contentShape(Circle()) }.buttonStyle(.plain).accessibilityLabel("Ayarlar ve oyun rehberi").accessibilityIdentifier("settings_button")
                    }.foregroundStyle(RustTheme.teal).padding(.horizontal, 24)
                    ZStack {
                        Circle().stroke(.white.opacity(0.45), lineWidth: 1).frame(width: 176, height: 176)
                        Circle().trim(from: 0, to: 0.72).stroke(.orange.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [2, 8])).frame(width: 190, height: 190).rotationEffect(.degrees(spin ? 360 : 0)).animation(.linear(duration: 12).repeatForever(autoreverses: false), value: spin)
                        Image("RustIcon").resizable().scaledToFit().frame(width: 154, height: 154).shadow(color: RustTheme.teal.opacity(0.3), radius: 15, y: 9)
                    }
                    .scaleEffect(entered ? 1 : 0.62).opacity(entered ? 1 : 0)

                    VStack(spacing: -5) {
                        Text("PASLANAN").foregroundStyle(.orange)
                        Text("BLOKLAR").foregroundStyle(.white)
                    }
                    .font(.system(size: 43, weight: .black, design: .serif))
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 3)
                    .padding(.horizontal, 28).padding(.vertical, 9)
                    .background(RustTheme.teal.opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
                    .brassBorder(radius: 15, width: 3)
                    .offset(y: entered ? 0 : 24).opacity(entered ? 1 : 0)

                    Text("YERLEŞTİR. PARÇALA. PASI YEN.")
                        .font(.caption.weight(.black)).tracking(1.25).foregroundStyle(RustTheme.ink)
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(.white.opacity(0.78), in: Capsule())

                    WorkshopDashboard(model: model)
                        .padding(.horizontal, 23)
                        .offset(y: entered ? 0 : 32).opacity(entered ? 1 : 0)

                    GlassCard {
                        VStack(spacing: 14) {
                            Label("ATÖLYE REKORU  •  \(model.bestScore)", systemImage: "crown.fill").font(.subheadline.monospacedDigit().weight(.black)).foregroundStyle(.brown).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                MenuFeature(icon: "hand.draw.fill", text: "SÜRÜKLE")
                                MenuFeature(icon: "sparkles", text: "TEMİZLE")
                                MenuFeature(icon: "hammer.fill", text: "PASI KIR")
                            }
                            Button(model.hasSavedRun ? "KALDIĞIN YERDEN DEVAM" : "ATÖLYEYİ ÇALIŞTIR") { model.hasSavedRun ? model.resume() : model.start() }.buttonStyle(PrimaryButton()).accessibilityIdentifier("start_button")
                        }
                    }
                    .padding(.horizontal, 23)
                    .offset(y: entered ? 0 : 42).opacity(entered ? 1 : 0)
                    Spacer().frame(height: max(18, proxy.safeAreaInsets.bottom + 8))
                }.frame(maxWidth: 460).frame(maxWidth: .infinity).frame(minHeight: proxy.size.height).padding(.vertical, 12) }.scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showSettings) { WorkshopSettings() }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { entered = true }
            spin = !reduceMotion
        }
    }
}

struct MenuFeature: View {
    let icon: String; let text: String
    var body: some View { VStack(spacing: 5) { Image(systemName: icon).font(.title3); Text(text).font(.system(size: 9, weight: .black)).lineLimit(1) }.foregroundStyle(RustTheme.teal).frame(maxWidth: .infinity).padding(.vertical, 9).background(RustTheme.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 10)) }
}

struct WorkshopDashboard: View {
    @ObservedObject var model: GameViewModel
    var goalProgress: Double { Double(model.bestScore) / Double((model.bestScore / 5_000 + 1) * 5_000) }
    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                HStack(spacing: 7) { Image(systemName: "hexagon.fill").foregroundStyle(.yellow); Text("\(model.coins)").font(.headline.monospacedDigit().weight(.black)); Text("COIN").font(.caption2.weight(.black)).foregroundStyle(.brown) }
                    .padding(.horizontal, 12).padding(.vertical, 9).background(.white.opacity(0.88), in: Capsule()).brassBorder(radius: 20)
                Button { model.openShop() } label: { Label("JOKER MAĞAZASI", systemImage: "cart.fill").font(.caption.weight(.black)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 10).background(RustTheme.teal, in: Capsule()).brassBorder(radius: 20) }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Label("ATÖLYE HEDEFİ", systemImage: "target").font(.caption2.weight(.black)); Spacer(); Text("\((model.bestScore / 5_000 + 1) * 5_000) PUAN").font(.caption2.weight(.black)).foregroundStyle(.brown) }
                    ProgressView(value: goalProgress).tint(.orange)
                    Text("Skor yükseldikçe coin kazan, joker stokla.").font(.system(size: 10, weight: .semibold)).foregroundStyle(.brown)
                }
                .padding(11).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 13)).brassBorder(radius: 13)
                HStack(spacing: -7) {
                    ForEach(PowerUp.allCases) { powerUp in
                        ZStack(alignment: .bottomTrailing) {
                            Image(powerUp.assetName).resizable().scaledToFit().frame(width: 43, height: 43)
                            Text("\(model.inventory(for: powerUp))").font(.system(size: 10, weight: .black)).foregroundStyle(.white).padding(4).background(RustTheme.teal, in: Circle())
                        }
                    }
                }
                .padding(8).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 13)).brassBorder(radius: 13)
            }
        }
    }
}

struct GameView: View {
    @ObservedObject var model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var boardFrame: CGRect = .zero
    @State private var draggedPiece: Piece?
    @State private var dragLocation: CGPoint = .zero
    @State private var hoverOrigin: GridPoint?
    @State private var lastDropStatus = "none"
    @State private var rustShake: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                VStack(spacing: 7) {
                    GameHeader(model: model)
                    MetricsBar(model: model)
                    BoardView(model: model, preview: previewPoints, previewIsValid: previewIsValid)
                        .frame(width: max(200, min(proxy.size.width - 30, proxy.size.height - 340)))
                        .onGeometryChange(for: CGRect.self) { proxy in proxy.frame(in: .named("gameSpace")) } action: { boardFrame = $0 }
                        .padding(.horizontal, 15)
                    RuleStrip()
                    PowerUpBar(model: model)
                    HStack(spacing: 9) {
                        ForEach(Array(model.hand.enumerated()), id: \.element.id) { index, piece in
                            PieceTray(piece: piece, index: index, isDragging: draggedPiece?.id == piece.id) { value in
                                guard model.phase == .playing, !model.isShopOpen, !model.needsRescue else { return }
                                draggedPiece = piece; dragLocation = value.location; hoverOrigin = boardOrigin(for: value.location)
                            } onEnded: { value in finishDrag(piece, at: value.location) }
                        }
                    }.padding(.horizontal, 15)
                    Text("TUT • SÜRÜKLE • BIRAK").font(.caption2.weight(.black)).tracking(1.8).foregroundStyle(RustTheme.teal)
                }
                .padding(.top, proxy.size.width >= 500 ? max(12, (proxy.size.height - min(proxy.size.width - 30, proxy.size.height - 340) - 360) / 2) : 12).padding(.bottom, 8)
                .modifier(ShakeEffect(amount: reduceMotion ? 0 : 3, animatableData: rustShake))

                #if DEBUG
                Color.clear.frame(width: 1, height: 1).accessibilityElement().accessibilityLabel("Drag debug").accessibilityValue(lastDropStatus).accessibilityIdentifier("drag_debug")
                Color.clear.frame(width: 1, height: 1).accessibilityElement().accessibilityLabel("Viewport debug").accessibilityValue("\(Int(boardFrame.minY))").accessibilityIdentifier("viewport_debug")
                #endif
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
            .coordinateSpace(name: "gameSpace")
            .overlay {
                ZStack {
                    if model.burstID != nil { if reduceMotion { Text("ÇİZGİ TEMİZLENDİ!").font(.headline).padding().background(RustTheme.sand, in: Capsule()) } else { SparkBurst().id(model.burstID) } }
                    if let event = model.placementEvent { PlacementBurst().id(event.id).position(cellCenter(for: event.origin)) }
                    if let event = model.powerEvent { PowerUpBurst(event: event).id(event.id).position(cellCenter(for: event.origin)) }
                    if model.rustEventID != nil && !reduceMotion { RustFlash().id(model.rustEventID) }
                    if model.coinEventID != nil { CoinRewardBurst().id(model.coinEventID) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height).clipped().allowsHitTesting(false)
            }
            .overlay {
                GeometryReader { _ in
                    if let piece = draggedPiece { FloatingPiece(piece: piece, valid: previewIsValid, cellSize: boardCellSize).position(floatingPosition(for: piece)).allowsHitTesting(false) }
                }
            }
            .onChange(of: model.rustEventID) { _, event in
                guard event != nil else { return }
                withAnimation(.linear(duration: 0.46)) { rustShake += 1 }
            }
        }
    }

    private var previewIsValid: Bool {
        guard let piece = draggedPiece, let origin = hoverOrigin else { return false }
        return model.engine.canPlace(piece, at: origin)
    }

    private var previewPoints: Set<GridPoint> {
        guard let piece = draggedPiece, let origin = hoverOrigin else { return [] }
        return Set(piece.points.map { .init(row: origin.row + $0.row, column: origin.column + $0.column) })
    }

    private func boardOrigin(for finger: CGPoint) -> GridPoint? {
        DragPlacementMapper.origin(for: finger, in: boardFrame)
    }

    private func finishDrag(_ piece: Piece, at location: CGPoint) {
        if let origin = boardOrigin(for: location), model.engine.canPlace(piece, at: origin) { lastDropStatus = "placed \(origin.row) \(origin.column)"; model.place(piece, at: origin) }
        else { lastDropStatus = "rejected x\(Int(location.x)) y\(Int(location.y)) board\(Int(boardFrame.minX)),\(Int(boardFrame.minY)),\(Int(boardFrame.width)),\(Int(boardFrame.height))"; GameAudio.shared.play(.invalid); Haptics.error() }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) { draggedPiece = nil; hoverOrigin = nil }
    }

    private func cellCenter(for point: GridPoint) -> CGPoint {
        let playable = boardFrame.insetBy(dx: 9, dy: 9), size = playable.width / 8
        return CGPoint(x: playable.minX + (CGFloat(point.column) + 0.5) * size, y: playable.minY + (CGFloat(point.row) + 0.5) * size)
    }

    private func floatingPosition(for piece: Piece) -> CGPoint {
        guard let origin = hoverOrigin, boardFrame.width > 0 else { return CGPoint(x: dragLocation.x, y: dragLocation.y - 72) }
        let step = boardCellSize + 3
        let shapeWidth = CGFloat(piece.points.map(\.column).max() ?? 0) * step + boardCellSize
        let shapeHeight = CGFloat(piece.points.map(\.row).max() ?? 0) * step + boardCellSize
        return CGPoint(
            x: boardFrame.minX + 8 + CGFloat(origin.column) * step + shapeWidth / 2,
            y: boardFrame.minY + 8 + CGFloat(origin.row) * step + shapeHeight / 2
        )
    }

    private var boardCellSize: CGFloat { max(1, (boardFrame.width - 16 - 21) / 8) }
}

struct GameHeader: View {
    @ObservedObject var model: GameViewModel
    var body: some View {
        HStack {
            Button { GameAudio.shared.play(.uiTap); model.phase = .paused } label: { Image(systemName: "line.3.horizontal").font(.title2.bold()).foregroundStyle(.white).frame(width: 45, height: 45).background(RustTheme.teal, in: RoundedRectangle(cornerRadius: 11)).brassBorder(radius: 11) }.accessibilityIdentifier("menu_button")
            Spacer()
            VStack(spacing: -3) { Text("PASLANAN").foregroundStyle(.orange); Text("BLOKLAR").foregroundStyle(.white) }.font(.system(size: 26, weight: .black, design: .serif)).shadow(color: .black.opacity(0.6), radius: 1, y: 2).padding(.horizontal, 22).padding(.vertical, 5).background(RustTheme.teal, in: RoundedRectangle(cornerRadius: 10)).brassBorder(radius: 10)
            Spacer()
            Button { model.openShop() } label: {
                VStack(spacing: 0) { Image(systemName: "hexagon.fill").font(.caption).foregroundStyle(.yellow); Text("\(model.coins)").font(.caption2.monospacedDigit().weight(.black)).foregroundStyle(.white) }
                    .frame(width: 45, height: 45).background(RustTheme.teal, in: RoundedRectangle(cornerRadius: 11)).brassBorder(radius: 11)
            }.accessibilityLabel("Joker mağazası").accessibilityValue("\(model.coins)").accessibilityIdentifier("shop_button")
        }.padding(.horizontal, 17)
    }
}

struct MetricsBar: View {
    @ObservedObject var model: GameViewModel
    var body: some View {
        HStack(spacing: 8) {
            MetricCard(title: "SKOR", value: model.engine.score, color: RustTheme.teal)
            VStack(spacing: 3) { Text("KOMBO x\(max(1, model.engine.combo))").font(.caption.bold()).foregroundStyle(.white); ProgressView(value: min(Double(model.engine.score) / 10_000, 1)).tint(.cyan) }.padding(8).frame(maxWidth: .infinity).background(RustTheme.teal, in: RoundedRectangle(cornerRadius: 9)).brassBorder(radius: 9)
            MetricCard(title: "HAMLE", value: model.engine.moves, color: .orange).accessibilityElement(children: .ignore).accessibilityLabel("Hamle").accessibilityValue("\(model.engine.moves)").accessibilityIdentifier("moves_label")
        }.padding(.horizontal, 15)
    }
}

struct MetricCard: View {
    let title: String; let value: Int; let color: Color
    var body: some View { VStack(spacing: 0) { Text(title).font(.caption2.bold()).foregroundStyle(.brown); Text("\(value)").font(.title2.monospacedDigit().weight(.black)).foregroundStyle(color) }.frame(maxWidth: .infinity).padding(.vertical, 6).background(Color(red: 1, green: 0.96, blue: 0.85), in: RoundedRectangle(cornerRadius: 9)).brassBorder(radius: 9) }
}

struct BoardView: View {
    @ObservedObject var model: GameViewModel
    let preview: Set<GridPoint>; let previewIsValid: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 8)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(model.engine.cells) { cell in CellView(cell: cell, invalid: model.invalidCell == cell.point, previewed: preview.contains(cell.point), previewIsValid: previewIsValid, powerTargeting: model.selectedPowerUp != nil).aspectRatio(1, contentMode: .fit).contentShape(Rectangle()).onTapGesture { model.useSelectedPowerUp(at: cell.point) }.accessibilityElement(children: .ignore).accessibilityLabel("Hücre \(cell.point.row) \(cell.point.column)").accessibilityValue(cell.state == .empty ? "empty" : "occupied").accessibilityIdentifier("cell_\(cell.point.row)_\(cell.point.column)") }
        }
        .padding(8).background(Color(red: 0.72, green: 0.62, blue: 0.48), in: RoundedRectangle(cornerRadius: 13)).brassBorder(radius: 13, width: 4).shadow(color: .brown.opacity(0.35), radius: 8, y: 5).accessibilityIdentifier("game_board")
    }
}

struct CellView: View {
    let cell: Cell; let invalid: Bool; let previewed: Bool; let previewIsValid: Bool; let powerTargeting: Bool
    @State private var popScale: CGFloat = 1
    var body: some View {
        ZStack {
            EmptySocket()
            switch cell.state {
            case .empty: EmptyView()
            case let .active(life, colorIndex):
                Image(BlockAsset.active(colorIndex)).resizable().scaledToFit()
                Circle().fill(.black.opacity(0.42)).frame(width: 25, height: 25).overlay {
                    Text("\(life)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white).shadow(color: .black, radius: 1)
                }
                if life <= 2 { RoundedRectangle(cornerRadius: 7).stroke(Color.orange.opacity(0.9), lineWidth: 2).shadow(color: .yellow, radius: 4) }
            case let .rusted(armor):
                Image("BlockRustV2").resizable().scaledToFit()
                HStack(spacing: 1.5) {
                    ForEach(0..<GameBalance.rustArmor, id: \.self) { index in
                        Circle().fill(index < armor ? Color.cyan : Color.black.opacity(0.32)).frame(width: 3.5, height: 3.5)
                    }
                }
                .padding(.horizontal, 4).padding(.vertical, 3)
                .background(.black.opacity(0.48), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(4)
            }
            if previewed { RoundedRectangle(cornerRadius: 5).fill((previewIsValid ? Color.cyan : Color.red).opacity(0.48)).overlay(RoundedRectangle(cornerRadius: 5).stroke(previewIsValid ? .white : .red, lineWidth: 2)) }
            if powerTargeting { RoundedRectangle(cornerRadius: 6).stroke(Color.yellow.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).shadow(color: .orange, radius: 3) }
        }.scaleEffect((invalid ? 0.85 : 1) * popScale).animation(.spring(response: 0.2), value: invalid)
            .onChange(of: cell.state) { oldValue, newValue in
                if oldValue == .empty, newValue != .empty { popScale = 0.62; withAnimation(.spring(response: 0.32, dampingFraction: 0.46)) { popScale = 1 } }
                if case .rusted = newValue { popScale = 1.18; withAnimation(.spring(response: 0.42, dampingFraction: 0.38)) { popScale = 1 } }
            }
    }
}

struct RuleStrip: View {
    var body: some View { HStack(spacing: 10) { Image(systemName: "info.circle.fill").font(.title).foregroundStyle(RustTheme.teal); VStack(alignment: .leading, spacing: 0) { Text("BLOKLAR 8 HAMLEDE PASLANIR").font(.caption2.weight(.black)); Text("Komşu çizgileri temizle, pas zırhını kır.").font(.caption2).foregroundStyle(.brown) }; Spacer(); Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").foregroundStyle(RustTheme.teal) }.padding(.horizontal, 14).padding(.vertical, 8).background(Color(red: 1, green: 0.96, blue: 0.85), in: RoundedRectangle(cornerRadius: 11)).brassBorder(radius: 11).padding(.horizontal, 15) }
}

struct PowerUpBar: View {
    @ObservedObject var model: GameViewModel
    var body: some View {
        HStack(spacing: 7) {
            ForEach(PowerUp.allCases) { powerUp in
                Button { model.select(powerUp) } label: {
                    HStack(spacing: 4) {
                        Image(powerUp.assetName).resizable().scaledToFit().frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: -1) {
                            Text(powerUp.shortTitle).font(.system(size: 10, weight: .black)).lineLimit(1).minimumScaleFactor(0.8)
                            Text("×\(model.inventory(for: powerUp))").font(.caption2.monospacedDigit().weight(.black)).foregroundStyle(model.inventory(for: powerUp) > 0 ? RustTheme.teal : .red)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 5)
                    .background(model.selectedPowerUp == powerUp ? Color.yellow.opacity(0.32) : Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.selectedPowerUp == powerUp ? Color.orange : Color.brown.opacity(0.35), lineWidth: model.selectedPowerUp == powerUp ? 2.5 : 1))
                    .shadow(color: model.selectedPowerUp == powerUp ? .orange.opacity(0.45) : .clear, radius: 6)
                }
                .buttonStyle(.plain).accessibilityLabel(powerUp.title).accessibilityValue("\(model.inventory(for: powerUp))").accessibilityIdentifier("power_\(powerUp.rawValue)")
            }
        }
        .overlay(alignment: .top) {
            if let selected = model.selectedPowerUp {
                Text("\(selected.shortTitle): TAHTADAN HEDEF SEÇ").font(.system(size: 9, weight: .black)).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 3).background(.orange, in: Capsule()).offset(y: -14)
            }
        }
        .padding(.horizontal, 15)
    }
}

struct StoreOverlay: View {
    @ObservedObject var model: GameViewModel
    @State private var entered = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea()
                AmbientSparkField(color: .yellow, count: 28)
                ScrollView { VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: -2) { Text("JOKER").foregroundStyle(.orange); Text("MAĞAZASI").foregroundStyle(.white) }.font(.system(size: 27, weight: .black, design: .rounded))
                        Spacer()
                        HStack(spacing: 5) { Image(systemName: "hexagon.fill").foregroundStyle(.yellow); Text("\(model.coins)").font(.headline.monospacedDigit().weight(.black)).foregroundStyle(.white) }.padding(.horizontal, 12).padding(.vertical, 8).background(RustTheme.teal, in: Capsule()).brassBorder(radius: 20)
                        Button { model.closeShop() } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background(.black.opacity(0.38), in: Circle()) }.accessibilityLabel("Mağazayı kapat").accessibilityIdentifier("shop_close")
                    }
                    Text("Puan yaptıkça coin kazan. Jokerleri stokla, pas bastığında atölyeyi kurtar.").font(.caption).foregroundStyle(.white.opacity(0.74)).fixedSize(horizontal: false, vertical: true)
                    ForEach(PowerUp.allCases) { powerUp in StoreItemCard(model: model, powerUp: powerUp) }
                    HStack { Image(systemName: "info.circle.fill"); Text("Her 100 puan = 1 coin").font(.caption.weight(.bold)); Spacer(); Text("ENVANTER KALICIDIR").font(.system(size: 9, weight: .black)) }.foregroundStyle(.white.opacity(0.74)).padding(.top, 3)
                }
                .padding(20) }.scrollIndicators(.hidden)
                .frame(height: min(480, proxy.size.height - 24))
                .frame(width: min(370, proxy.size.width - 28))
                .background(Color(red: 0.055, green: 0.16, blue: 0.16).opacity(0.98), in: RoundedRectangle(cornerRadius: 25))
                .brassBorder(radius: 25, width: 4).shadow(color: .orange.opacity(0.55), radius: 30)
                .opacity(entered ? 1 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.2)) { entered = true } }
    }
}

struct StoreItemCard: View {
    @ObservedObject var model: GameViewModel
    let powerUp: PowerUp
    var affordable: Bool { model.coins >= powerUp.cost }
    var body: some View {
        HStack(spacing: 12) {
            Image(powerUp.assetName).resizable().scaledToFit().frame(width: 68, height: 68).shadow(color: .cyan.opacity(0.32), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(powerUp.title).font(.subheadline.weight(.black)).foregroundStyle(.white)
                Text(powerUp.detail).font(.caption2).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
                Text("Stok: \(model.inventory(for: powerUp))").font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(.cyan)
            }
            Spacer(minLength: 2)
            Button { model.buy(powerUp) } label: {
                VStack(spacing: 1) { Image(systemName: "hexagon.fill").foregroundStyle(.yellow); Text("\(powerUp.cost)").font(.caption.monospacedDigit().weight(.black)).foregroundStyle(.white) }
                    .frame(width: 52, height: 52).background(affordable ? RustTheme.teal : Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 12)).brassBorder(radius: 12)
            }.buttonStyle(.plain).disabled(!affordable).accessibilityLabel("\(powerUp.title), \(powerUp.cost) coin karşılığında al").accessibilityIdentifier("buy_\(powerUp.rawValue)")
        }
        .padding(11).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.16)))
    }
}

struct PieceTray: View {
    let piece: Piece; let index: Int; let isDragging: Bool
    let onChanged: (DragGesture.Value) -> Void; let onEnded: (DragGesture.Value) -> Void
    var body: some View {
        GeometryReader { proxy in
            let columns = (piece.points.map(\.column).max() ?? 0) + 1
            let rows = (piece.points.map(\.row).max() ?? 0) + 1
            let widthUnits = 1 + CGFloat(columns - 1) * 0.88
            let heightUnits = 1 + CGFloat(rows - 1) * 0.88
            let cellSize = min(43, (proxy.size.width - 18) / widthUnits, (proxy.size.height - 18) / heightUnits)
            PieceShape(piece: piece, cellSize: cellSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 106, maxHeight: 106)
        .background(LinearGradient(colors: [trayColor.opacity(0.85), trayColor, RustTheme.ink.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1).padding(5).allowsHitTesting(false))
        .brassBorder(radius: 15, width: 3).shadow(color: .brown.opacity(0.3), radius: 5, y: 3).opacity(isDragging ? 0.28 : 1)
            .contentShape(Rectangle()).highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("gameSpace")).onChanged(onChanged).onEnded(onEnded)).accessibilityElement(children: .ignore).accessibilityLabel("Parça \(index + 1)").accessibilityValue(piece.id.uuidString).accessibilityIdentifier("piece_\(index)")
    }
    private var trayColor: Color { BlockAsset.trayColor(piece.colorIndex) }
}

struct PieceShape: View {
    let piece: Piece; let cellSize: CGFloat; var cellStep: CGFloat? = nil
    var body: some View {
        let maxRow = piece.points.map(\.row).max() ?? 0; let maxColumn = piece.points.map(\.column).max() ?? 0
        let step = cellStep ?? cellSize * 0.88
        ZStack(alignment: .topLeading) { ForEach(piece.points, id: \.self) { point in TileSprite(colorIndex: piece.colorIndex).frame(width: cellSize, height: cellSize).offset(x: CGFloat(point.column) * step, y: CGFloat(point.row) * step) } }
            .frame(width: CGFloat(maxColumn) * step + cellSize, height: CGFloat(maxRow) * step + cellSize, alignment: .topLeading)
    }
}

enum BlockAsset {
    static func active(_ colorIndex: Int) -> String {
        switch colorIndex % 4 {
        case 0: "BlockTealV2"
        case 1: "BlockAmberV2"
        case 2: "BlockBlueV2"
        default: "BlockVioletV2"
        }
    }

    static func trayColor(_ colorIndex: Int) -> Color {
        switch colorIndex % 4 {
        case 0: Color(red: 0.08, green: 0.64, blue: 0.62)
        case 1: Color(red: 0.98, green: 0.65, blue: 0.06)
        case 2: Color(red: 0.08, green: 0.48, blue: 0.82)
        default: Color(red: 0.47, green: 0.24, blue: 0.72)
        }
    }
}

struct TileSprite: View {
    let colorIndex: Int
    var body: some View { Image(BlockAsset.active(colorIndex)).resizable().scaledToFit().shadow(color: .black.opacity(0.25), radius: 2, y: 1.5) }
}

struct FloatingPiece: View {
    let piece: Piece; let valid: Bool; let cellSize: CGFloat
    var body: some View { PieceShape(piece: piece, cellSize: cellSize, cellStep: cellSize + 3).opacity(0.96).shadow(color: valid ? .cyan.opacity(0.7) : .red.opacity(0.65), radius: 7, y: 2) }
}

struct PlacementBurst: View {
    @State private var expanded = false
    var body: some View { ZStack { Circle().stroke(Color.cyan, lineWidth: 4).frame(width: expanded ? 76 : 8, height: expanded ? 76 : 8).opacity(expanded ? 0 : 0.9); ForEach(0..<18, id: \.self) { index in Capsule().fill(index.isMultiple(of: 2) ? Color.white : .yellow).frame(width: 4, height: 10).rotationEffect(.radians(Double(index) * .pi / 9)).offset(x: expanded ? CGFloat(cos(Double(index) * .pi / 9) * 44) : 0, y: expanded ? CGFloat(sin(Double(index) * .pi / 9) * 44) : 0).opacity(expanded ? 0 : 1) } }.onAppear { withAnimation(.easeOut(duration: 0.52)) { expanded = true } } }
}

struct PowerUpBurst: View {
    let event: PowerEvent
    @State private var explode = false
    private var color: Color { switch event.powerUp { case .rustSolvent: .cyan; case .blast: .orange; case .rewind: .purple } }
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(explode ? 0 : 0.5)).frame(width: explode ? 210 : 18, height: explode ? 210 : 18)
            Circle().stroke(.white, lineWidth: 7).frame(width: explode ? 185 : 12, height: explode ? 185 : 12).opacity(explode ? 0 : 1)
            ForEach(0..<30, id: \.self) { index in
                let angle = Double(index) * 2.3999
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "diamond.fill")
                    .font(.system(size: CGFloat(5 + index % 8), weight: .black)).foregroundStyle(index.isMultiple(of: 4) ? .white : color)
                    .offset(x: explode ? CGFloat(cos(angle)) * CGFloat(52 + index % 9 * 9) : 0, y: explode ? CGFloat(sin(angle)) * CGFloat(52 + index % 9 * 9) : 0)
                    .rotationEffect(.radians(explode ? angle * 3 : angle)).opacity(explode ? 0 : 1)
            }
            Image(event.powerUp.assetName).resizable().scaledToFit().frame(width: 74, height: 74).shadow(color: color, radius: 16).scaleEffect(explode ? 1.55 : 0.45).opacity(explode ? 0 : 1)
        }
        .frame(width: 250, height: 250)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { explode = true } }
    }
}

struct CoinRewardBurst: View {
    @State private var rise = false
    var body: some View {
        HStack(spacing: 5) { Image(systemName: "hexagon.fill").foregroundStyle(.yellow); Text("+ COIN").font(.headline.weight(.black)).foregroundStyle(.white) }
            .padding(.horizontal, 14).padding(.vertical, 8).background(RustTheme.teal, in: Capsule()).brassBorder(radius: 22).shadow(color: .yellow, radius: 12)
            .offset(y: rise ? -170 : -80).scaleEffect(rise ? 1.12 : 0.6).opacity(rise ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.75)) { rise = true } }
    }
}

struct RustFlash: View {
    @State private var explode = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(colors: [Color.orange.opacity(explode ? 0 : 0.62), Color.red.opacity(explode ? 0 : 0.2), .clear], center: .center, startRadius: 0, endRadius: proxy.size.height * 0.62).ignoresSafeArea()
                Circle().stroke(LinearGradient(colors: [.white, .yellow, .orange], startPoint: .top, endPoint: .bottom), lineWidth: 10).frame(width: explode ? 430 : 20, height: explode ? 430 : 20).opacity(explode ? 0 : 0.95)
                ForEach(0..<42, id: \.self) { index in
                    let angle = Double(index) * 2.39996
                    let distance = CGFloat(95 + (index % 9) * 18)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index.isMultiple(of: 4) ? Color.yellow : Color(red: 0.58, green: 0.16, blue: 0.04))
                        .frame(width: CGFloat(5 + index % 7), height: CGFloat(9 + index % 13))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(.orange.opacity(0.8), lineWidth: 1))
                        .rotationEffect(.radians(explode ? angle * 3.2 : angle))
                        .offset(x: explode ? CGFloat(cos(angle)) * distance : 0, y: explode ? CGFloat(sin(angle)) * distance : 0)
                        .opacity(explode ? 0 : 1)
                }
                VStack(spacing: -2) {
                    Text("⚠︎").font(.system(size: 34, weight: .black))
                    Text("PASLANDI!").font(.system(size: 33, weight: .black, design: .rounded))
                    Text("ZIRH OLUŞTU").font(.caption.weight(.black)).tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color(red: 0.24, green: 0.07, blue: 0.02).opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                .brassBorder(radius: 16, width: 3)
                .shadow(color: .orange, radius: 20)
                .scaleEffect(explode ? 1.38 : 0.42).opacity(explode ? 0 : 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.92)) { explode = true } }
    }
}

struct SparkBurst: View {
    @State private var explode = false
    var body: some View {
        ZStack {
            Rectangle().fill(LinearGradient(colors: [.clear, .yellow, .white, .yellow, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 430, height: explode ? 2 : 28).opacity(explode ? 0 : 0.95).shadow(color: .orange, radius: 18)
            ForEach(0..<3, id: \.self) { ring in Circle().stroke(ring == 0 ? .white : .yellow, lineWidth: CGFloat(10 - ring * 2)).frame(width: explode ? CGFloat(360 + ring * 95) : 20, height: explode ? CGFloat(360 + ring * 95) : 20).opacity(explode ? 0 : 0.88) }
            ForEach(0..<72, id: \.self) { i in
                let angle = Double(i) * 2.39996
                Capsule().fill(i.isMultiple(of: 4) ? Color.white : (i.isMultiple(of: 3) ? Color.yellow : .orange)).frame(width: CGFloat(3 + i % 4), height: CGFloat(8 + i % 18)).rotationEffect(.radians(angle)).offset(x: explode ? CGFloat(cos(angle)) * CGFloat(95 + i * 3) : 0, y: explode ? CGFloat(sin(angle)) * CGFloat(70 + i * 2) : 0).opacity(explode ? 0 : 1)
            }
            VStack(spacing: -2) { Text("MÜKEMMEL!").font(.caption.weight(.black)).tracking(2); Text("ÇİZGİ TEMİZLENDİ!").font(.title2.weight(.black)) }.foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 10).background(.orange, in: RoundedRectangle(cornerRadius: 14)).brassBorder(radius: 14, width: 3).shadow(color: .yellow, radius: 22).scaleEffect(explode ? 1.42 : 0.45).opacity(explode ? 0 : 1)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.08)) { explode = true } }
    }
}

struct BrassBorder: ViewModifier {
    let radius: CGFloat; let width: CGFloat
    func body(content: Content) -> some View { content.overlay(RoundedRectangle(cornerRadius: radius).stroke(LinearGradient(colors: [.white, .yellow, .orange, .brown], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width)) }
}
extension View { func brassBorder(radius: CGFloat, width: CGFloat = 2) -> some View { modifier(BrassBorder(radius: radius, width: width)) } }

struct PauseOverlay: View {
    @ObservedObject var model: GameViewModel
    @State private var entered = false
    @State private var showSettings = false
    @State private var confirmRestart = false
    var body: some View {
        Color.black.opacity(0.64).ignoresSafeArea().overlay {
            ZStack {
                AmbientSparkField(color: .orange, count: 20)
                VStack(spacing: 14) {
                    ZStack { Image(systemName: "gearshape.2.fill").font(.system(size: 70)).foregroundStyle(.orange); Image(systemName: "pause.fill").font(.title).foregroundStyle(.white) }
                    Text("ATÖLYE DURDU").font(.title2.weight(.black)).foregroundStyle(.white)
                    Text("Dişli hazır. Devam ettiğinde sayaç kaldığı yerden işler.").font(.caption).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.72))
                    Button("DEVAM ET") { GameAudio.shared.play(.uiTap); model.phase = .playing }.buttonStyle(PrimaryButton())
                    Button { model.openShop() } label: { Label("JOKER MAĞAZASI  •  \(model.coins)", systemImage: "cart.fill").font(.subheadline.weight(.black)).foregroundStyle(.yellow) }
                    Button("SES VE OYUN REHBERİ") { showSettings = true }.font(.subheadline.bold()).foregroundStyle(.white).padding(.vertical, 6)
                    Button("YENİDEN BAŞLAT") { confirmRestart = true }.font(.headline).foregroundStyle(.orange).padding(.vertical, 6)
                    Button("ANA MENÜ") { GameAudio.shared.play(.uiTap); model.phase = .menu }.font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.82))
                }
                .padding(24).frame(width: 300)
                .background(Color(red: 0.07, green: 0.18, blue: 0.18).opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
                .brassBorder(radius: 22, width: 4).shadow(color: .orange.opacity(0.48), radius: 28)
                .opacity(entered ? 1 : 0)
            }
        }
        .sheet(isPresented: $showSettings) { WorkshopSettings() }
        .confirmationDialog("Mevcut tahta silinip yeni oyun başlatılacak. Coin ve jokerlerin korunur.", isPresented: $confirmRestart, titleVisibility: .visible) { Button("Yeni oyun", role: .destructive) { model.start() } }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { entered = true } }
    }
}

struct GameOverView: View {
    @ObservedObject var model: GameViewModel
    @State private var entered = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42).ignoresSafeArea()
                AmbientSparkField(color: .orange, count: 42)
                ForEach(0..<24, id: \.self) { index in
                    Image("BlockRustV2").resizable().frame(width: CGFloat(16 + index % 5 * 4), height: CGFloat(16 + index % 5 * 4))
                        .rotationEffect(.degrees(entered ? Double(index * 57) : 0))
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.3)
                        .offset(x: entered ? CGFloat(cos(Double(index) * 2.4)) * CGFloat(80 + index * 5) : 0, y: entered ? CGFloat(sin(Double(index) * 2.4)) * CGFloat(70 + index * 4) : 0)
                        .opacity(entered ? 0 : 0.85)
                }
                ScrollView { VStack(spacing: 15) {
                    Spacer().frame(height: max(44, proxy.safeAreaInsets.top + 16))
                    Image("BlockRustV2").resizable().scaledToFit().frame(width: 104, height: 104).shadow(color: .orange, radius: 22).scaleEffect(entered ? 1 : 0.35)
                    Text("ATÖLYE PAYDOSU").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white).shadow(color: .orange, radius: 8)
                    Text("SKOR").font(.caption.weight(.black)).tracking(3).foregroundStyle(.orange)
                    Text("\(model.engine.score)").font(.system(size: 64, weight: .black, design: .rounded)).foregroundStyle(.white).monospacedDigit()
                    HStack(spacing: 6) { Image(systemName: "hexagon.fill").foregroundStyle(.yellow); Text("\(model.coins) COIN").font(.subheadline.monospacedDigit().weight(.black)).foregroundStyle(.white) }.padding(.horizontal, 13).padding(.vertical, 7).background(RustTheme.teal, in: Capsule()).brassBorder(radius: 18)
                    GlassCard { VStack(spacing: 12) { StatRow(label: "Bu tur kazanılan coin", value: model.engine.score / 100); StatRow(label: "Temizlenen çizgi", value: model.engine.stats.linesCleared); StatRow(label: "Kırılan pas", value: model.engine.stats.rustBroken); Divider(); StatRow(label: "Atölye rekoru", value: model.bestScore) } }.padding(.horizontal, 25)
                    Button("YENİDEN ATEŞLE") { model.start() }.buttonStyle(PrimaryButton()).padding(.horizontal, 34)
                    Button { model.openShop() } label: { Label("JOKER MAĞAZASI", systemImage: "cart.fill").font(.subheadline.weight(.black)).foregroundStyle(.yellow) }
                    Button("ANA MENÜ") { GameAudio.shared.play(.uiTap); model.phase = .menu }.font(.subheadline.weight(.black)).foregroundStyle(.white)
                    Spacer(minLength: 18)
                }.frame(maxWidth: 460).frame(maxWidth: .infinity).frame(minHeight: proxy.size.height) }.scrollIndicators(.hidden)
                .offset(y: entered ? 0 : 45).opacity(entered ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { entered = true } }
    }
}

struct StatRow: View { let label: String; let value: Int; var body: some View { HStack { Text(label); Spacer(); Text("\(value)").monospacedDigit().bold() } } }
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline.weight(.black)).foregroundStyle(.white).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 14).padding(.vertical, 16)
            .background(LinearGradient(colors: [RustTheme.mint, RustTheme.teal, Color(red: 0.02, green: 0.31, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
            .brassBorder(radius: 16, width: 2).shadow(color: RustTheme.teal.opacity(0.3), radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct AmbientSparkField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color; let count: Int
    @State private var active = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let x = CGFloat((index * 47) % 101) / 100 * proxy.size.width
                    let startY = CGFloat((index * 83) % 100) / 100 * proxy.size.height
                    Circle().fill(index.isMultiple(of: 5) ? .white : color).frame(width: CGFloat(2 + index % 4), height: CGFloat(2 + index % 4))
                        .position(x: x, y: active ? startY - CGFloat(30 + index % 9 * 10) : startY + 20)
                        .opacity(active ? 0.08 : 0.78)
                        .shadow(color: color, radius: 4)
                        .animation(.easeOut(duration: Double(1.1 + Double(index % 7) * 0.13)).repeatForever(autoreverses: false).delay(Double(index % 11) * 0.07), value: active)
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true).onAppear { active = !reduceMotion }
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 8), y: 0))
    }
}

#Preview { ContentView() }
