# Gameseeker — iPad Gamepad Overlay

iPad'e bağlı oyun kolunun tuş basışlarını ekranda **anlık** gösteren bir iPad uygulaması.
gamepadviewer.com'un iPad'e özel hali gibi düşünebilirsin: tuşlar, tetikler ve analog çubuklar
basıldığı anda ekrandaki temsili kolda yanar.

## Önemli: iPadOS kısıtı

İstenen senaryo, App Store'daki **Fortnite uygulaması açıkken** Gameseeker'ın arka planda çalışıp
tuşları oyunun üstünde göstermesiydi. iPadOS bu senaryoya iki noktada izin vermiyor:

1. **Başka uygulamanın üstüne çizim yapılamıyor.** iPadOS'ta Android'deki gibi "diğer uygulamaların
   üzerinde göster" izni yok.
2. **Arka plandaki uygulama kol girdisini okuyamıyor.** GameController çerçevesi kol girdisini
   yalnızca ön plandaki uygulamaya iletir. Bu davranışı açmaya yarayan
   `GCController.shouldMonitorBackgroundEvents` ayarı yalnızca macOS'ta çalışır; Apple'ın
   belgelerine göre iOS ve iPadOS'ta yok sayılır.

Bu yüzden Gameseeker **oyunu kendi içinde açar** ve overlay'i oyunun hemen üstüne çizer:

| Mod | Ne yapar |
| --- | --- |
| **Oyna + Overlay** | Xbox Cloud Gaming, GeForce NOW ya da Gamepad API kullanan herhangi bir web oyununu uygulamanın içinde tam ekran açar. Kol overlay'i oyunun üstünde durur; sürüklenebilir, boyutlandırılabilir, opaklığı ayarlanabilir. **Fortnite**, Xbox Cloud Gaming'de ücretsiz oynanabiliyor (Game Pass gerekmez, Microsoft hesabı yeterli). |
| **İzleyici modu** | Tam ekran gamepad görünümü. Koyu, siyah ya da yeşil/mavi/magenta perde arka planı seçilebilir. Kayıt ya da yayın için uygun. |

iPad'in kendi ekran kaydı (Denetim Merkezi › Ekran Kaydı), "Oyna + Overlay" modunda overlay'i de kaydeder.

## Özellikler

- Xbox, PlayStation (DualSense / DualShock 4), Nintendo Switch Pro ve MFi kollar.
- Kol tipi otomatik algılanır; tuş etiketleri buna göre değişir (A/B/X/Y, ✕/○/□/△, LB/L1, LT/L2...).
- Analog tetikler dolum çubuğuyla, analog çubuklar konum ve yön çizgisiyle gösterilir.
- ProMotion ekranlarda saniyede 120 kez okunur.
- "Son basılan tuşlar" şeridi, eksen değerleri (drift kontrolü için), pil durumu.
- Vurgu rengi, renkli yüz tuşları, gövdeli/gövdesiz görünüm, overlay için koyu arka panel.
- **Yerel kol köprüsü:** WKWebView içindeki Gamepad API kolu her zaman algılayamıyor. Köprü, uygulamanın
  okuduğu kol değerlerini oyuna standart bir gamepad olarak iletir. Böylece oyun ile overlay her zaman
  aynı girdiyi görür. Sorun çıkarsa Ayarlar'dan kapatılabilir.

## Kurulum

Proje bir **Swift Playgrounds uygulama paketi** (`Gameseeker.swiftpm`). Hem iPad'de Swift Playgrounds
ile hem de Mac'te Xcode ile açılabilir.

### A) Sadece iPad ile (Mac gerekmez)

1. App Store'dan **Swift Playgrounds** uygulamasını indir.
2. Bu depoyu iPad'de Safari ile aç: **Code › Download ZIP**.
3. **Dosyalar** uygulamasında ZIP'e dokunarak aç, sonra `Gameseeker.swiftpm` klasörüne dokun.
   Klasör Swift Playgrounds'ta açılır.
4. **▶︎ Çalıştır** düğmesine bas. Uygulama tam ekran açılır.

### B) Mac + Xcode ile (ana ekrana kurulur)

1. `Gameseeker.swiftpm` klasörünü Xcode'da aç.
2. Hedefin **Signing & Capabilities** sekmesinden Apple hesabını (Team) seç. Gerekirse
   bundle identifier'ı benzersiz bir değerle değiştir.
3. iPad'i kabloyla bağla, hedef olarak seç ve **Run** ile kur. Ücretsiz Apple hesabıyla imzalanan
   uygulamalar 7 gün geçerlidir; süre dolunca yeniden kurman gerekir.

Gereksinim: iPadOS 17 veya üstü.

## Kullanım

1. Kolu **Ayarlar › Bluetooth** üzerinden iPad'e eşleştir. Ana ekrandaki önizleme tuşlara tepki verir.
2. **Oyna + Overlay**'e dokun. Varsayılan servis Xbox Cloud Gaming. Fortnite'ı doğrudan açmak için
   Ayarlar › Bulut oyun › **Fortnite (Xbox Cloud)** seçeneğini kullan.
3. Oyundayken sol üstteki kol simgesine dokun:
   - **Overlay'i düzenle:** overlay'i sürükle, iki parmakla büyüt/küçült, opaklığı ayarla.
   - **Overlay'i gizle/göster**, **Geri**, **Yenile**, **Servis ana sayfası**, **Oyundan çık**.
4. Düzenleme dışındayken overlay dokunmaları geçirir; ekrana yapılan dokunuşlar oyuna gider.

## Proje yapısı

```
Gameseeker.swiftpm/
├── Package.swift               Uygulama tanımı (Swift Playgrounds / Xcode)
├── App/                        Giriş noktası, ortak görünümler ve tema
├── Model/
│   ├── ControllerManager.swift Kolu bulur, her ekran karesinde durumu okur
│   ├── PadTypes.swift          Tuşlar, kol tipleri, durum modeli
│   └── AppSettings.swift       Kalıcı ayarlar
├── Gamepad/
│   ├── GamepadView.swift       Kol çizimi (SwiftUI Canvas)
│   └── LiveViews.swift         Canlı önizleme, tuş geçmişi, eksen değerleri
├── Screens/                    Ana ekran, oyun + overlay, izleyici, ayarlar
└── Web/
    ├── GameWebView.swift       Bulut oyun için ayarlanmış WKWebView
    └── GamepadBridge.swift     Kol → web Gamepad API köprüsü
```

Her push'ta GitHub Actions projeyi iOS Simulator için derler (`.github/workflows/build.yml`).

## Kaynaklar

- [Apple: `shouldMonitorBackgroundEvents`](https://developer.apple.com/documentation/gamecontroller/gccontroller/shouldmonitorbackgroundevents) (iOS/tvOS'ta yok sayılır)
- [Apple Developer Forums: arka planda kol olaylarını dinleme](https://developer.apple.com/forums/thread/130653)
- [WebKit Bug 269292: Gamepad API WKWebView'da çalışmıyor](https://bugs.webkit.org/show_bug.cgi?id=269292)
