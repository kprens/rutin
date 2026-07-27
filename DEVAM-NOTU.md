# Rutin — Yayın Devam Notu (Android)

Paket: `com.alper.rutin` · Sürüm: `1.0.0+1` · Play hesap ID: `6203518488595330095`

## Tamamlananlar
- Kod doğrulandı: `flutter analyze`/`test` temiz, 15 test geçti.
- `compileSdk 36` yapıldı (min 23 / target 35 değişmedi) — build hatası çözüldü.
- **Signed `.aab` üretildi:** `build/app/outputs/bundle/release/app-release.aab` (imza: `/Users/tekiz/rutin-release.jks`, alias `rutin`). **Keystore'u YEDEKLE.**
- Supabase: `verify-receipt` **deploy edildi**, `link` yapıldı (ref `pfgljdvkmkqvlvdljvjk`).
  - Secret'lar: `GOOGLE_PACKAGE_NAME=com.alper.rutin` **set edildi**.
  - `delete_user` SQL **çalıştırıldı** (Success).
  - `config.toml` eklendi (`verify_jwt=false`).
- Play Console: uygulama oluşturuldu, `.aab` **internal testing**'e yüklendi (Play App Signing devraldı).
- Testers + License testing eklendi (`ahmetselimtekiz@gmail.com`).
- Abonelikler **etkin**: `rutin_pro_monthly` (aylık, ~₺79,99 tüketici) + `rutin_pro_yearly` (yıllık, ~₺399,99). Auto-renewing.

## ŞU AN BURADAYIM (sıradaki adım)
**Servis hesabı JSON'u → Supabase secret** (KRİTİK — bu olmadan satın almalar `valid:false`, Pro açılmaz).
- Sayfa: `https://play.google.com/console/u/0/developers/6203518488595330095/api-access`
- Google Cloud projesi bağla → **servis hesabı oluştur** (ad: `rutin-verify`).
- Sonra Play'de bu hesaba izin ver: **Finansal verileri görüntüle** + **Siparişleri ve abonelikleri yönet**.
- Google Cloud Console'da JSON key indir (Keys → Add key → JSON).
- Terminalde secret'a ekle:
  ```bash
  cd ~/Downloads/rutin
  supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/indirdigin.json)"
  ```

## KALAN adımlar
1. (yukarıdaki) Servis hesabı JSON → secret.
2. İsteğe bağlı: yıllık plana **7 gün ücretsiz deneme** teklifi ekle.
3. Play "App content": **Veri Güvenliği** formu (AdMob reklam + ATT), **Gizlilik Politikası URL'i** (`gizlilik-politikasi.md` yayınla), **Hesap Silme** beyanı (uygulama içi `delete_user` var).
4. Store listing (açıklama, ekran görüntüleri, ikon, feature graphic — `store/` klasöründe hazır materyaller var).
5. İnternal test cihazında **gerçek satın alma testi** (license tester → ücret alınmaz → Pro açılmalı).
6. Production'a çıkış (review).

## Notlar / riskler
- KGP uyarısı ve 25 eski paket: yayından SONRA, teker teker güncelle. Şimdi dokunma.
- Sentry atlandı (opsiyonel). `build_release.sh`'ta SENTRY_DSN boş.
- Ödeme ekranı gelmeden Pro açılması SADECE debug build'de olur (`kDebugMode`); release'de olmaz — sorun değil.
