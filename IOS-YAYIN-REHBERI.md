# Rutin — iOS (App Store) Yayın & IAP Kurulum Rehberi

Bu belge, uygulamayı App Store'a çıkarmak için **senin mağaza tarafında** yapman
gereken adımları sıralar. Kod tarafı (in_app_purchase entegrasyonu, gerçek
satın alma, "Geri Yükle" düğmesi) hazır — aşağıdaki ürün kimliklerini birebir
aynı tanımlaman yeterli.

> **Kodla eşleşmesi ZORUNLU ürün kimlikleri**
> - Aylık: `rutin_pro_monthly`
> - Yıllık: `rutin_pro_yearly`
>
> (Kaynak: `lib/iap.dart` → `Iap.monthlyId` / `Iap.yearlyId`. Değiştirirsen ikisini de değiştir.)

---

## 0. Ön koşullar
- **Mac + Xcode** (iOS build ve arşivleme yalnızca macOS'ta yapılır).
- Bir **Apple ID**.
- Fiziksel bir iPhone (test için; sende var — K.prens).

## 1. Apple Developer Program üyeliği
- https://developer.apple.com/programs/ üzerinden kaydol.
- **Ücret: yılda 99 USD** (Play'deki tek seferlik 25 $'dan farklı, her yıl yenilenir).
- Apple kimlik doğrulaması yapar; onay genelde birkaç saat–2 gün sürer.
- Bu tamamlanmadan App Store Connect'e uygulama yükleyemezsin.

## 2. Paid Agreements (Banka/Vergi) — IAP için ŞART
- App Store Connect → **Agreements, Tax, and Banking**.
- "Paid Applications" sözleşmesini kabul et, banka + vergi bilgisini gir.
- **Bu tamamlanmadan abonelik ürünlerin uygulamaya YÜKLENMEZ** (fiyatlar boş gelir).

## 3. App Store Connect'te uygulama kaydı
- App Store Connect → **Apps → +** → New App.
- Platform: iOS, dil, isim (**Rutin**), Bundle ID (Xcode'daki `PRODUCT_BUNDLE_IDENTIFIER` ile aynı olmalı; portalda kayıtlı değilse önce **Certificates, Identifiers & Profiles → Identifiers**'tan ekle).
- SKU: serbest bir metin (örn. `rutin-001`).

## 4. Abonelik ürünlerini oluştur
App Store Connect → uygulaman → **Subscriptions** (Monetization):
1. Bir **Subscription Group** oluştur (örn. "Rutin Pro").
2. Grup içinde iki abonelik ekle — **ID'ler kodla birebir aynı**:
   - `rutin_pro_monthly` → aylık, fiyat kademesi ~₺79,99
   - `rutin_pro_yearly` → yıllık, fiyat kademesi ~₺399,99
3. Her ürün için: yerelleştirilmiş ad + açıklama (TR ve EN), fiyat, gözden geçirme ekran görüntüsü.
4. Durum **"Ready to Submit"** olmalı.

> Not: "7 gün ücretsiz deneme" istiyorsan her ürüne **Introductory Offer → Free Trial**
> ekle. Eklemezsen buton metninde deneme vaadi olmamalı (kodda zaten "Rutin Pro'ya geç"
> yaptık, yanlış vaat yok).

## 5. Xcode: StoreKit capability + imzalama
- `ios/Runner.xcworkspace`'i Xcode'da aç.
- **Signing & Capabilities** → Team'ini seç (otomatik imzalama).
- **+ Capability → In-App Purchase** ekle.

## 6. ATT + Gizlilik (AdMob kullandığın için)
- `ios/Runner/Info.plist`'e ekle: `NSUserTrackingUsageDescription` (örn. "Reklamları
  ilgi alanlarına göre göstermek için izin istenir.").
- İlk açılışta ATT izin diyaloğu göster (google_mobile_ads ATT akışı).
- App Store Connect → **App Privacy**: hangi veriyi topladığını beyan et; gizlilik
  politikası URL'sini gir (hazır: `kprens.github.io/rutin-legal`).

## 7. Sürüm bilgisi + görseller
- Ekran görüntüleri: **6.7"** (iPhone 15/16 Pro Max) ve gerekiyorsa 6.5" boyutları.
- Açıklama, anahtar kelimeler, kategori (Health & Fitness / Productivity), yaş sınırı.
- Sürüm numarası ve build numarası (`pubspec.yaml` → `version:`).

## 8. Build'i yükle (Mac'te)
```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ipa
```
Sonra Xcode → **Product → Archive** → **Distribute App → App Store Connect → Upload**
(veya Transporter uygulamasıyla `.ipa` yükle).

## 9. Sandbox'ta IAP testi (ÖNEMLİ)
- App Store Connect → **Users and Access → Sandbox → Testers**: bir sandbox test
  hesabı oluştur (gerçek olmayan e-posta).
- iPhone → Ayarlar → App Store → Sandbox Account ile o hesaba gir.
- TestFlight/debug build'de satın almayı dene — **gerçek para gitmez**. "Geri Yükle"
  düğmesini de test et.

## 10. İncelemeye gönder
- İlk gönderimde **abonelik ürünlerini build ile aynı gönderiye ekle** (Apple IAP'yi
  ilk kez uygulamayla birlikte inceler).
- **App Review Information** → Notes'a sandbox/test hesabı bilgisini ve "Pro nasıl
  test edilir" adımını yaz.
- Gönder. Onay genelde 24–48 saatte sonuçlanır.

---

## Reddedilmeyi önleyen kontrol listesi
- [x] Dijital abonelik yalnızca Apple IAP ile satılıyor (harici ödeme/yönlendirme yok).
- [x] **"Satın alımları geri yükle"** düğmesi var (Apple zorunlu tutar).
- [x] Yanıltıcı "ücretsiz deneme" vaadi yok (offer tanımlamadıysan).
- [x] Geliştirici test düğmesi yalnızca debug build'de görünür (release'te yok).
- [ ] Uygulama çökmüyor, tüm butonlar çalışıyor (App Review çökmeye çok takılır).
- [ ] App Privacy beyanı + gizlilik politikası URL'si dolu.
- [ ] ATT izin metni ve akışı ekli.

## Kod tarafında hazır olanlar
- `lib/iap.dart` — in_app_purchase servisi (ürün yükleme, satın alma, geri yükleme,
  purchaseStream dinleme, Pro kilidi).
- `lib/main.dart` — açılışta `Iap.instance.init(...)`.
- `lib/screens/paywall_screen.dart` — gerçek satın alma butonu, mağaza fiyatları,
  "Geri Yükle" düğmesi, debug-only test düğmesi.
- `pubspec.yaml` — `in_app_purchase: ^3.3.0`.

> Güvenlik notu (v1): Satın alma, sunucu tarafı makbuz doğrulaması olmadan mağaza
> sinyaliyle açılıyor. İndie için kabul edilebilir. İleride Supabase Edge Function
> ile makbuz doğrulaması eklenebilir.
