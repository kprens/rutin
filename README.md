# Rutin — Alışkanlık Takip Uygulaması

Streak sayacı, günlük checklist, su takibi ve takvim. Flutter ile tek kod tabanından Android + iOS.

Veri katmanı buluta hazır: `lib/repository.dart` içindeki `Repository` arayüzü sayesinde
sosyal katman geldiğinde `LocalRepository` yerine Firebase/Supabase tabanlı bir depo
tek satırla takılır — ekran kodlarına dokunmadan.

## Kurulum (ilk kez)

1. **Flutter SDK'yı kur:** https://docs.flutter.dev/get-started/install
   (macOS/Windows/Linux fark etmez; "Android" hedefini seç.)
2. **Android Studio'yu kur** (Android SDK ve emülatör için): https://developer.android.com/studio
3. Kurulumu doğrula:
   ```
   flutter doctor
   ```
   Android bölümü yeşil olana kadar `flutter doctor` un dediklerini yap.

## Projeyi çalıştırma

Bu klasörde platform dosyaları (android/, ios/) yok — Flutter bunları tek komutla üretir:

```
cd rutin
flutter create . --org com.alper --project-name rutin
flutter pub get
flutter run
```

Telefonunu USB ile bağlayıp geliştirici modunu açarsan `flutter run` doğrudan telefonda başlatır;
yoksa Android Studio'daki emülatörde açılır.

## Bildirim izinleri (Android)

`flutter create .` ürettikten sonra `android/app/src/main/AndroidManifest.xml` dosyasında
`<manifest>` etiketinin hemen içine şu satırları ekle:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

Su hatırlatıcısı uygulama kapalıyken de çalışır (48 saatlik zincir kurulur, uygulama her
açılışta tazelenir) ve 22:00–08:00 arası sessizdir.

## Dosya yapısı

```
lib/
  main.dart            — uygulama girişi, tema, alt sekmeler
  theme.dart           — sıcak renk paleti (prototiple aynı)
  models.dart          — veri modelleri (JSON'a çevrilebilir, buluta hazır)
  repository.dart      — veri deposu soyutlaması (yerel ⇄ bulut geçişi burada)
  store.dart           — uygulama durumu ve iş mantığı
  notifications.dart   — yerel bildirimler
  widgets.dart         — ortak parçalar
  screens/
    today_screen.dart    — Bugün: program + checklist
    water_screen.dart    — Su takibi + hatırlatıcı
    calendar_screen.dart — Haftalık / aylık takvim
    streaks_screen.dart  — Streak sayaçları
```

## Yol haritası

- [x] Faz 1 — MVP: streak, checklist, su, takvim, yerel bildirim, yerel veri
- [ ] Faz 2 — istatistikler, ilerleme grafikleri, görev tekrarları
- [ ] Faz 3 — sosyal katman: hesap, bulut senkronu, arkadaşların streak'lerini görme
