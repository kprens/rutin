# Rutin — Yayın Öncesi Kontrol Listesi

Son güncelleme: 2026-07-12 · Sürüm: pubspec `version: 0.1.0` (UI'da "v1.0.0" yazıyor — **tutarsız**, hizala)

---

## 0. Bu oturumda yapılan düzeltmeler

- **Build hatası giderildi:** `AppState.changeGoal(int)` eksikti; `lib/ui/water_screen.dart` (ve eski `lib/screens/water_screen.dart`) çağırıyordu. `lib/store.dart`'a eklendi (1–20 bardak sınırı).
- **Bildirim toggle'ları gerçek sisteme bağlandı:** Push + Günlük Hatırlatma kapalıyken su/akşam/takvim hatırlatıcıları zamanlanmıyor ve açık olanlar iptal ediliyor (`applyNotificationSettings`, `cancelAllReminders`).
- **Kriz ekranı** yeni koyu mor/teal tasarıma taşındı: `lib/ui/crisis_screen.dart`. `openSos` artık bunu açıyor.
- **Auth ekranı** Supabase'e hazır seam ile yeniden yazıldı (`lib/auth.dart` → `AuthService`/`LocalAuthService`). Gerçek backend yok.

---

## 1. iOS Info.plist (~70. satır)

**Durum: XML geçerli.** `xmllint --noout ios/Runner/Info.plist` hata vermiyor; dosya iyi biçimli.

69–70. satırlardaki blok (commit edilmemiş) tam da eksik olan anahtardı:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-2837265476679803~9045016421</string>
```

Bu anahtar olmadan `google_mobile_ads` uygulamayı açılışta **çökertir**
("The Google Mobile Ads SDK was initialized without a GADApplicationIdentifier").
Eklenmesiyle çökme çözülür. Yani "70. satır hatası" = eksik GADApplicationIdentifier → **giderildi.**

**Ama üretim için düzeltilecekler:**

- iOS ID'si (`ca-app-pub-2837265476679803~…`) ile Android ID'si (aşağıda) **uyuşmuyor**; Android hâlâ Google **test** ID'sinde. İkisi de kendi AdMob hesabındaki gerçek uygulama ID'leri olmalı.
- App Store için önerilen ek anahtarlar eksik: `SKAdNetworkItems` (Google'ın SKAdNetwork ID listesi) ve kişiselleştirilmiş reklam/ATT kullanılacaksa `NSUserTrackingUsageDescription`.
- Bildirim izni açıklaması gerekmiyor (yerel bildirim izni runtime'da isteniyor) ama kamera/foto vb. izin yok — sorun değil.

---

## 2. Poppins fontu — DOĞRULAMA SONUCU: bundle EDİLMEMİŞ

- `pubspec.yaml`'da `fonts:` bölümü **yok**.
- Projede hiç `.ttf`/`.otf` dosyası **yok** (`assets/fonts/` klasörü yok).
- Temada (`buildRutinDarkTheme`, `lib/ui/rutin_ui.dart`) `fontFamily` **ayarlı değil**; Poppins yalnızca yorum satırlarında geçiyor.

**Sonuç:** Uygulama şu an platform varsayılan fontuyla çıkıyor (iOS: SF Pro, Android: Roboto). Screenshot'lardaki yuvarlak tipografi için Poppins istiyorsan:

1. `assets/fonts/` altına Poppins .ttf dosyalarını koy (Regular/Medium/SemiBold/Bold).
2. `pubspec.yaml`:
   ```yaml
   flutter:
     fonts:
       - family: Poppins
         fonts:
           - asset: assets/fonts/Poppins-Regular.ttf
           - asset: assets/fonts/Poppins-Medium.ttf
             weight: 500
           - asset: assets/fonts/Poppins-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Poppins-Bold.ttf
             weight: 700
   ```
3. `buildRutinDarkTheme()` içindeki `ThemeData(...)`'a `fontFamily: 'Poppins'` ekle.

> Karar senin: font eklemezsek de uygulama sorunsuz çalışır, sadece görünüm varsayılan fonttadır.

---

## 3. AdMob — üretim eksikleri

| Öğe | Durum | Yapılacak |
|---|---|---|
| `lib/ads.dart` banner ID | Google **TEST** ID (`…3940256099942544/6300978111`) | Gerçek reklam birimi ID'si |
| Android `APPLICATION_ID` (AndroidManifest.xml:33) | Google **TEST** ID (`…3940256099942544~3347511713`) | Gerçek Android uygulama ID'si |
| iOS `GADApplicationIdentifier` | Gerçek görünen ama Android'le **uyumsuz** ID | iOS gerçek ID; iki platformu aynı hesapla eşle |
| `MobileAds.instance.initialize()` | **Çağrılmıyor** (yalnızca eski `main.dart.bak`'ta) | Kullanılacaksa `bootRutin`'de başlat |
| `AdBanner` widget'ı | Yeni UI'da **hiç kullanılmıyor** | Ekrana yerleştir ya da bağımlılığı kaldır |

**Önemli karar:** Yayınlanan uygulamada (`main_ui.dart` → `main.dart`) AdMob tamamen devre dışı — `ads.dart` hiçbir yerden import edilmiyor. İki seçenek:
- **A) Reklam istemiyorsan:** `google_mobile_ads` bağımlılığını ve `ads.dart`'ı kaldır, iOS'tan `GADApplicationIdentifier`'ı sil. (En temiz v1.)
- **B) Reklam istiyorsan:** `bootRutin`'de `Ads.init()` çağır, `RootShell`'e Pro değilse `AdBanner` ekle, gerçek ID'leri gir.

---

## 4. Sentry — üretim eksikleri

- `lib/main.dart:17` → `const _sentryDsn = '';` → Sentry **kapalı**. DSN boşken uygulama Sentry'siz açılıyor (kod doğru, sadece DSN yok).
- **Yapılacak:** sentry.io'da proje aç, DSN'i `--dart-define=SENTRY_DSN=...` ile ver ve koddan oku (DSN'i repoya gömme). `tracesSampleRate: 0.2` makul; üretimde 0.1–0.2 arası tut.

---

## 5. Supabase — üretim eksikleri

- Yayınlanan uygulama Supabase'i **hiç başlatmıyor** (`Supabase.initialize` yeni kod yolunda yok). `supabase_flutter` bağımlılığı şu an kullanılmıyor.
- `lib/auth.dart` yerel stub (`LocalAuthService`) — gerçek giriş yok.
- Eski `lib/social.dart` Supabase.initialize içeriyor ama **hardcoded anonKey** ile ve yalnızca kullanılmayan `friends_screen`'den çağrılıyor. Anahtarı koddan çıkar.
- Şemalar hazır: `supabase_schema.sql`, `supabase_delete_user.sql`.

**Supabase'e geçiş yapılacaklar:**
1. `bootRutin`'de `await Supabase.initialize(url: ..., anonKey: ...)` (değerleri `--dart-define` ile).
2. `AuthService` arayüzüne `SupabaseAuthService` yaz, `auth.dart`'taki `authService` sabitini değiştir (ekran değişmez).
3. `Repository` arayüzüne `CloudRepository` yaz (repository.dart deseni hazır); senkron/çakışma stratejisi belirle.
4. `supabase_schema.sql` uygula, **RLS politikalarını** aç, hesap silme için `supabase_delete_user.sql` fonksiyonunu kur.
5. Google/Apple OAuth redirect URL'lerini Supabase panelinde tanımla.

---

## 6. Genel yayın kontrol listesi

**Sürüm & kimlik**
- [ ] `pubspec.yaml` sürümü ile UI'daki "v1.0.0" metnini hizala.
- [ ] iOS `PRODUCT_BUNDLE_IDENTIFIER` ve Android `applicationId` gerçek paket adı.
- [ ] İmzalama: Android release keystore (commit'te "Release imza yapılandırması" var — doğrula), iOS provisioning profilleri.

**İkonlar & görsel**
- [ ] `flutter_launcher_icons` çalıştırıldı (`assets/icon/icon.png` mevcut).
- [ ] Açılış ekranı (LaunchScreen) doğru.

**İzinler & uyum**
- [ ] iOS: gerekiyorsa `NSUserTrackingUsageDescription` (ATT).
- [ ] Gizlilik: `gizlilik-politikasi.md` yayın URL'sine bağlı; App Store/Play "Veri Güvenliği" formu (`MAGAZA-VERI-GUVENLIGI.md`) dolduruldu.
- [ ] Hesap silme akışı store gereği çalışıyor (`wipeAllData` + Supabase kullanılıyorsa sunucu tarafı silme).

**IAP**
- [ ] `rutin_pro_monthly` / `rutin_pro_yearly` ürünleri App Store Connect + Play Console'da **birebir** tanımlı.
- [ ] Sandbox/test hesabıyla satın alma + "Restore" test edildi.

**Kalite**
- [ ] `flutter analyze` temiz (aşağıya bak).
- [ ] Gerçek cihazda: bildirim izni, hatırlatıcı zamanlama, gün değişimi (rollover) test edildi.
- [ ] Boş durum (hiç habit/streak yok) ve dolu durum ekranları kontrol edildi.

**Temizlik (bkz. §7)**
- [ ] `lib/main.dart.bak` ve kullanılmayan `lib/screens/*` + `coach/social/ads/widgets` dosyaları hakkında karar verildi.

---

## 7. Ölü kod analizi (`lib/screens/*` ve yardımcılar)

Yeni giriş noktası `main_ui.dart → main.dart` **yalnızca** `lib/ui/*` + `store/models/l10n/notifications/repository/iap/auth/theme` dosyalarını kullanıyor. Aşağıdakiler yeni build'de **hiçbir yerden import edilmiyor** (ölü kod):

| Dosya | Durum | Yeni karşılığı |
|---|---|---|
| `lib/screens/today_screen.dart` | Ölü | `ui/home_screen.dart` |
| `lib/screens/water_screen.dart` | Ölü | `ui/water_screen.dart` |
| `lib/screens/calendar_screen.dart` | Ölü | `ui/calendar_screen.dart` |
| `lib/screens/stats_screen.dart` | Ölü | `ui/analytics_screen.dart` |
| `lib/screens/streaks_screen.dart` | Ölü | `ui/recovery_screen.dart` |
| `lib/screens/paywall_screen.dart` | Ölü | `ui/paywall_screen.dart` |
| `lib/screens/onboarding_screen.dart` | Ölü | `ui/onboarding_screen.dart` |
| `lib/screens/celebration_screen.dart` | Ölü | `ui/celebration_screen.dart` |
| `lib/screens/crisis_screen.dart` | Ölü | `ui/crisis_screen.dart` (bu oturumda taşındı) |
| `lib/screens/coach_screen.dart` | Ölü | Karşılığı yok (Coach özelliği yeni UI'da yok) |
| `lib/screens/friends_screen.dart` | Ölü | Karşılığı yok (Sosyal/arkadaş özelliği yok) |
| `lib/screens/themes_screen.dart` | Ölü | Karşılığı yok (yeni UI tek koyu tema) |
| `lib/coach.dart` | Ölü | Yalnızca eski screens kullanıyor |
| `lib/social.dart` | Ölü | Yalnızca `friends_screen` kullanıyor (hardcoded anonKey içerir) |
| `lib/ads.dart` | Ölü/yetim | Hiç import edilmiyor (bkz. §3) |
| `lib/widgets.dart` | Ölü | Yalnızca eski screens kullanıyor |
| `lib/main.dart.bak` | Yedek | Derlenmiyor; silinebilir |

**`lib/theme.dart` — SİLME.** Hâlâ canlı: `store.dart` içindeki `currentTheme` / `themeById` bunu kullanıyor. Ancak yeni UI görsel olarak `RC` token'larını kullandığı için tema sisteminin işlevi yok; ileride `store.dart`'tan tema alanları çıkarılırsa `theme.dart` da kaldırılabilir (ayrı refactor).

**Öneri (güvenli sıra):**
1. Önce `lib/main.dart.bak`'ı sil (yedek).
2. `flutter analyze` çalıştır, `main_ui.dart`'ı bir kez çalıştırıp doğrula.
3. Sonra tüm `lib/screens/` klasörünü + `coach.dart`, `social.dart`, `widgets.dart`, `ads.dart`'ı (reklam istemiyorsan) sil.
4. Tekrar `flutter analyze` + build. Hepsi git'te olduğu için geri alınabilir.

> Bu silmeleri **otomatik yapmadım** (yıkıcı işlem). Onaylarsan tek adımda temizleyebilirim.

---

## 8. Not: `flutter run` / `flutter analyze`

Bu ortamda Flutter SDK olmadığı için `flutter run -t lib/main_ui.dart` fiilen çalıştırılamadı; hatalar **statik analizle** (import/sembol izleme) tespit edildi. Erişilebilir ağaçtaki tek engelleyici derleme hatası `changeGoal` idi ve giderildi. Kendi makinende doğrulama:

```bash
flutter pub get
flutter analyze
flutter run -t lib/main_ui.dart
```
