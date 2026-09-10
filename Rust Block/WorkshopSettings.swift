import SwiftUI

struct WorkshopSettings: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rust8.sound", store: GameStorage.defaults) private var sound = true
    @AppStorage("rust8.music", store: GameStorage.defaults) private var music = true
    @AppStorage("rust8.haptics", store: GameStorage.defaults) private var haptics = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("ATÖLYENİN RİTMİ", systemImage: "waveform").font(.title2.weight(.black)).foregroundStyle(RustTheme.teal)
                    GlassCard { VStack(spacing: 18) {
                        Toggle("Ses efektleri", isOn: $sound).accessibilityIdentifier("sound_toggle")
                        Toggle("Atölye müziği", isOn: $music)
                        Toggle("Dokunsal geri bildirim", isOn: $haptics)
                    }.tint(RustTheme.teal) }
                    Label("NASIL OYNANIR?", systemImage: "hand.draw.fill").font(.headline).foregroundStyle(RustTheme.teal)
                    GlassCard { VStack(alignment: .leading, spacing: 16) {
                        guide("01", "Sürükle ve yerleştir", "Alttaki parçayı boş hücrelere sürükle. Bırakmadan önce tahtadaki önizlemeyi kontrol et; kullanılan parçanın yerine yenisi gelir.")
                        guide("02", "Çizgiyi tamamla", "Aktif bloklarla bir satır veya sütunu doldur. Aynı hamlede birden fazla çizgi temizlemek bonus puan kazandırır.")
                        guide("03", "Pası yönet", "Her yerleştirmede sayaçlar azalır. 8 hamlede paslanan bloklar yer kaplar. Yanlarındaki çizgileri temizleyerek pas zırhını azalt.")
                        guide("04", "Jokerle kurtar", "Jokeri seç, ardından hedef hücreye dokun. Her 100 puan bir coin kazandırır. Mağaza yalnızca oyun içi coin kullanır; gerçek para harcanmaz.")
                    } }
                    DisclosureGroup("Gizlilik ve oyun verileri") {
                        Text("Oyun hesap, reklam veya takip sistemi kullanmaz; geliştiriciye veri göndermez. Rekor, coin, jokerler, ayarlar ve devam eden oyun bu cihazda saklanır. Uygulamayı silmek bu verileri kaldırabilir. iCloud yedeği açıksa cihaz yedeğine dahil olabilir.").font(.subheadline).padding(.vertical, 10)
                    }.tint(RustTheme.teal)
                    Text("PASLANAN BLOKLAR • 1.0\nMola verdiğinde oyun durur. Kaldığın yerden devam edebilirsin.").font(.caption).foregroundStyle(.secondary)
                }.padding(22).frame(maxWidth: 550).frame(maxWidth: .infinity)
            }.background(RustTheme.sand).navigationTitle("Atölye rehberi").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { dismiss() } } }
        }
        .onAppear { GameAudio.shared.setMusicActive(false) }
    }
    private func guide(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.monospaced().bold()).foregroundStyle(.white).padding(9).background(RustTheme.teal, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct RescueOverlay: View {
    @ObservedObject var model: GameViewModel
    var body: some View {
        Color.black.opacity(0.65).ignoresSafeArea().overlay {
            GlassCard { VStack(spacing: 18) {
                Image(systemName: "wrench.and.screwdriver.fill").font(.largeTitle).foregroundStyle(RustTheme.teal)
                Text("BİR ÇIKIŞ YOLU VAR").font(.title3.weight(.black))
                Text("Bu parçalar için yer kalmadı. Bir jokerle alan açabilir veya skorunu kaydedip turu bitirebilirsin.").font(.subheadline).multilineTextAlignment(.center)
                ForEach([PowerUp.blast, .rustSolvent]) { power in
                    Button("\(power.title) • \(model.inventory(for: power))") {
                        model.select(power)
                    }.buttonStyle(PrimaryButton())
                }
                Button("TURU BİTİR") { model.endGame() }.font(.headline).foregroundStyle(RustTheme.teal).padding(10)
            } }.padding(25).frame(maxWidth: 390)
        }
    }
}
