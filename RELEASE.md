# Paslanan Bloklar — 1.0 yayın hazırlığı

Bu dosya yerel hazırlık kaydıdır; App Store onayı veya yükleme tamamlandı anlamına gelmez.

## Uygulama

- iOS 18.0+, iPhone dikey; iPad dikey/yatay, genişliği sınırlandırılmış tahta.
- Türkçe arayüz. Üç joker, yalnızca kazanılan oyun içi coin ile mağaza.
- Rekor, envanter, ses tercihleri ve devam eden oyun cihazda saklanır.
- Gerçek para satın alma, reklam SDK’sı, hesap, analitik veya takip yok.
- Ses, müzik ve dokunsal geri bildirim ayrı kapatılabilir. Müzik sessiz anahtarına uyar; diğer uygulamaların sesiyle karışabilir.
- Arka planda duraklama, yeniden başlatma onayı, bozuk kayıt kontrolü ve ayrı UI test veri alanı.
- PrivacyInfo.xcprivacy: UserDefaults / CA92.1; veri toplama ve takip yok.
- Debug önizleme/reset parametreleri Release sürümünde çalışmaz.
- Sesler Tools/generate_sfx.py ile özgün olarak sentezlenmiştir; üçüncü taraf müzik kullanılmamıştır.
- AppIcon.png, yerleşik imagegen ile eski şeffaf ikon referans alınarak opak olarak yeniden üretildi; 1024×1024 RGB/alpha yokluğu doğrulandı. Üretim talimatı: “Sekiz turkuaz emaye/paslı bakır bloğun düzenini koru; yalnızca şeffaf arka planı tam kaplayan koyu petrol emaye, hafif fırça dokusu ve altın kenar ışığıyla değiştir. Metin, dış çerçeve veya yuvarlatılmış dış maske ekleme; köşeler dahil tamamen opak olsun.” Kaynak çıktı: exec-1f6a7e60-75eb-4af4-a3e8-d0b4a2e41bda.png.

## Tekrarlanabilir kontroller

```sh
swiftc 'Rust Block/GameModels.swift' 'Rust Block/GameStorage.swift' Tests/EngineSmoke.swift -o /tmp/rust8-engine-smoke
/tmp/rust8-engine-smoke
python3 Tools/check_audio.py
xcodebuild test -project 'Rust Block.xcodeproj' -scheme 'Rust Block' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild archive -project 'Rust Block.xcodeproj' -scheme 'Rust Block' -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/RustBlock.xcarchive CODE_SIGNING_ALLOWED=NO
```

İmzasız arşiv yalnızca derleme ve paket içeriği kontrolüdür. Dağıtım için Organizer üzerinden uygun imzalama, Validate App ve TestFlight gerekir.

## 10 Eylül 2026 yerel QA kaydı

- Kullanıcı tercihi: yalnızca simülatör. Bağlı fiziksel iPhone’a kurulum/test yapılmadı.
- Motor: yerleştirme, çizgi temizleme, paslanma, joker sınırları, sürükleme eşlemesi, kayıt doğrulama ve 1.000 hamle stres testi geçti.
- Ses: 11 stereo dosyanın teknik kontrolleri geçti; kırpılma yok, 20 saniyelik müzik döngüsünün sınır farkı 0.000458. Bu kontrol fiziksel cihazda dinleme değerlendirmesinin yerine geçmez.
- iPhone 17 Pro: önceki son tam koşuda 5/5 UI testi geçti. iPhone 16e: ilk koşuda 4/5, ayar/ekran testi düzeltme sonrası ayrı koşuda geçti. Bu telefon koşuları son iPad/modal değişikliklerinden öncedir.
- iPad Pro 13 (M5), iOS 26.3.1: altı senaryolu koşuda 5/6 geçti; mağaza kapanışına erken dokunma hatası bulundu. İç içe ölçek animasyonları kaldırıldı. Mağaza/kurtarma ve ayarlar/tüm sayfalar tekrarında 2/2 geçti; tamamlanmış oyunun geri yüklenmediği doğrulandı.
- Satır patlama ve sürükleme sırasında tahta/ekran çerçevesinin değişmediği UI testlerinde doğrulandı. Tepsi parçasının kullanıldıktan hemen sonra yenilenmesi, coin ile satın alma, joker kullanımı ve kayıt devamı geçti.
- Son üretim kodundan `/tmp/RustBlock-Final-Sept10.xcarchive` oluşturuldu. `Tools/check_release.py` metadata, gizlilik manifesti, opak ikon, sesler, debug bayraklarının yokluğu ve imzayı doğruladı. İmza Apple Development’tır; dağıtım/Connect doğrulaması değildir.
- Test kanıtları: `/tmp/rust8-ipad-final-sept10.xcresult`, `/tmp/rust8-ipad-modal-retest.xcresult`. Geçici dizinler kalıcı teslim arşivi değildir.
- Son ekran tekrarı: `/tmp/rust8-ipad-screen-capture.xcresult`, 1/1 geçti. XCTest uygulama-penceresi görüntüsünün yatay yöndeki kırpılmasını önlemek için QA yakalaması `XCUIScreen.main.screenshot()` kullanır. Tam ekran görüntüsünde yatay tahta ve tepsiler görsel olarak doğrulandı.

İmzalı yerel arşivi kontrol etmek için:

```sh
python3 Tools/check_release.py /tmp/RustBlock-Final-Sept10.xcarchive
```

## Mağaza metni taslağı

Ad: Paslanan Bloklar

Alt başlık: Yerleştir, parçala, pası yen

Açıklama:

Atölyeyi çalıştır! Renkli metal parçaları 8×8 tahtaya sürükle, satır ve sütunları tamamla. Her hamlede blokların sayacı azalır: çizgileri zamanında temizle, pasın tahtayı ele geçirmesini önle.

Pas sökücüyle engelleri kaldır, blok bombasıyla alan aç, ömür yağıyla bir bloğa zaman kazandır. Puanlarından kazandığın coin’lerle joker stokla ve kendi rekoruna meydan oku.

• Sürükle-bırak blok bulmacası
• Pas sayaçları ve çoklu çizgi bonusları
• Üç farklı joker ve oyun içi mağaza
• Özgün atölye müziği, mekanik efektler ve dokunsal geri bildirim
• Çevrimdışı oyun ve kaldığın yerden devam

Anahtar kelime taslağı: blok,bulmaca,pas,zeka,atölye,çevrimdışı,metal,joker

İnceleme notu: Giriş gerekmez. İlk ekrandaki düğme oyunu başlatır. Parçaları alttan tahtaya sürükleyin. Her 100 puan 1 oyun içi coin kazandırır. Mağaza gerçek para veya uygulama içi satın alma kullanmaz. Ayarlar ve oyun rehberinde gizlilik metni bulunur.

## Yayın öncesi kalan sahip işlemleri

- [ ] Destek e-postasını ve kalıcı HTTPS destek/gizlilik URL’lerini belirle; STORE-POLICY.md metnini gözden geçirip yayınla. Sahte URL girme.
- [ ] App Store Connect uygulama kaydı, isim uygunluğu, kategori, fiyat, ülkeler, yaş derecelendirme anketi, telif bilgileri ve gizlilik beyanını doldur.
- [ ] Mevcut görsel varlıkların üretim/kullanım haklarını doğrula ve kayıtlarını sakla.
- [ ] Dağıtım imzası/provisioning ile Validate App ve TestFlight yüklemesi yap. Yerelde yalnız Apple Development kimliği görüldü.
- [ ] Gerçek iPhone/iPad’de sessiz anahtarı, Bluetooth/kulaklık, telefon çağrısı, dokunsal geri bildirim, ısınma ve uzun oyun oturumunu test et. Simülatör bu kontrollerin yerine geçmez.
- [ ] iOS 18 çalışma zamanı testi yap; yerel simülatör testleri iOS 26.3 çalışma zamanında yapılmıştır.
- [ ] VoiceOver ile tam oyun oynanabilirliği ve çok büyük yazı boyutlarını ayrıca değerlendir; doğrulanmamış erişilebilirlik etiketlerini mağazada ilan etme.
- [ ] Son imzalı sürümden doğru iPhone/iPad boyutlarında mağaza ekran görüntüleri üret. QA görüntüleri mağaza görseli değildir.
- [ ] TestFlight geri bildiriminden sonra dağıt. Kabul oranı, tekrar oynama veya “bağımlılık” garantisi yoktur.

Apple kaynakları:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Required reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
