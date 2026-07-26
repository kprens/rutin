# Rutin — Production Release Raporu

Tarih: 2026-07-16 (2. tur doğrulama) · Sürüm: `1.0.0+1` · Paket: `com.alper.rutin`

Kapsam kuralları uygulandı: **UI/UX değişmedi**, çalışan yapı korundu,
gereksiz refactor yapılmadı; yalnızca release'i engelleyen **kritik eksik**
tamamlandı.

> **Ortam notu:** Bu ortamda **Flutter/Dart/Android SDK yok** ve release
> keystore (`/Users/tekiz/rutin-release.jks`) bağlı klasörün dışında; bu yüzden
> `flutter test`, `flutter analyze` ve `.aab` üretimi **burada çalıştırılamaz**.
> Tüm kod/config statik olarak (import bütünlüğü, test sembolleri, imza ayarı,
> AdMob/Supabase config'leri satır satır) doğrulandı; `build_release.sh` gerçek
> `flutter` stub'ıyla uçtan uca **çalıştırılıp** doğru komutu ürettiği teyit
> edildi. Nihai `test`/`analyze`/build senin makinende çalıştırılmalı (bkz. §4).

---

## 1. Bu turda yapılan değişiklik

**`supabase/config.toml` — YENİ (bu tur, deploy kritik enabler)**
Klasörde `config.toml` yoktu; bu dosya olmadan `supabase functions deploy`
bu dizinden **çalışmaz** ("Cannot find project ref / config" hatası). Eklenen
minimal config, `supabase link` sonrası deploy'u mümkün kılar ve
`[functions.verify-receipt] verify_jwt = false` ayarını içerir. Bu ayar kritik:
istemci (`lib/iap.dart`) doğrulama isteğini **Authorization header'ı olmadan**
atıyor; `verify_jwt` kapatılmazsa gateway 401 döner, hiçbir satın alma
doğrulanamaz, Pro açılmaz. Ayar sayesinde deploy sırasında `--no-verify-jwt`
bayrağını unutma riski de ortadan kalkar. App kodu / şema **değişmedi**.

**Aşağıdakiler önceki turlardan; bu turda kod satır satır yeniden doğrulandı:**

**`build_release.sh` — placeholder guard (release güvenlik ağı)**
Script eskiden doldurulmamış placeholder'larla da build üretiyordu; bu, mağazaya
**TEST reklamlı** veya **bozuk Supabase bağlantılı** bir sürüm göndermek demekti
(AdMob politika ihlali + gelir yok + Pro asla açılmaz). Eklenen preflight kontrol,
`flutter build`'den **önce** çalışır:

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` doldurulmamışsa → **build durur** (exit 1).
- AdMob banner ID'leri hâlâ Google TEST birimiyse (`...3940256099942544`) → **durur**.
- `SENTRY_DSN` boşsa → yalnızca **uyarır** (uygulama Sentry'siz de çalışır, engellemez).

Sentinel string'ler dosyadaki placeholder'larla birebir eşleşecek şekilde yazıldı;
gerçek değerler girildiğinde false-positive vermez. `bash -n` ve stub `flutter`
ile hem "engelle" hem "geç" senaryoları test edildi. App kodu **değişmedi**.

**Önceki turdan gelen kod değişikliği (bu turda yeniden doğrulandı):**
`AuthService.deleteAccount()` (`lib/auth.dart`) + `wipeAllData()` içinden çağrısı
(`lib/store.dart`). "Hesabı Sil" artık Supabase'deki `auth.users` kaydını da
siliyor (`rpc('delete_user')`), mağaza zorunluluğunu karşılıyor. RPC/ağ hatası
tamamen `deleteAccount()` içinde yutuluyor → yerel silme her koşulda tamamlanıyor.

## 2. Doğrulanan mevcut yapı (değişiklik gerekmedi)

- **AdMob production ID'leri — tam ve tutarlı.** Dört kimlik de aynı hesaptan
  (`ca-app-pub-2837265476679803`) ve platforma özel:
  Android app `~4926851592` (`gradle.properties`), iOS app `~9045016421`
  (`Info.plist`), Android banner `/9987606580`, iOS banner `/8538793547`
  (`build_release.sh`). Kodda TEST ID'leri yalnızca **fallback default** olarak var.
- **verify-receipt Edge Function** — tam implemente. Google Play (servis hesabı
  JWT → OAuth → `purchases.subscriptions.get`, `paymentState` + `expiryTimeMillis`)
  ve Apple (`verifyReceipt`, **21007 → sandbox fallback**, `status==0` +
  `expires_date_ms`). Hatada `200 + {valid:false}` (istemci sözleşmesine uygun).
- **IAP istemci akışı** (`lib/iap.dart`) — satın alma sinyali tek başına Pro
  açmıyor; yalnızca Edge Function `{valid:true}` dönerse açılıyor. `restore()`
  aynı doğrulamadan geçiyor. `verifyReceiptUrl`, `main.dart`'ta `SUPABASE_URL`'den
  otomatik türetiliyor. Ürünler: `rutin_pro_monthly`, `rutin_pro_yearly`.
- **Android release** — `compileSdk/targetSdk=35`, `minSdk=23`,
  `signingConfigs.release ← key.properties`. Manifest: `INTERNET`,
  `POST_NOTIFICATIONS`, AdMob `APPLICATION_ID=${admobAppId}`, `label="Rutin"`.
- **iOS** — `GADApplicationIdentifier`, `NSUserTrackingUsageDescription`,
  SKAdNetwork kimlikleri mevcut.
- **Import bütünlüğü** — silinen dosyalara (`coach.dart`, `social.dart`,
  `widgets.dart`, eski `screens/*`) kalan referans **yok**; `themes_screen.dart`
  doğru şekilde `ui/paywall_screen.dart`'a bağlı.
- **Test** (`test/widget_test.dart`) — kullandığı tüm semboller imza uyumlu,
  platform kanalına bağımsız → emülatörsüz geçmeli.
- **Sır sızıntısı yok** — `key.properties` ve `*.jks` gitignore'da, izlenen sır yok.

---

## 3. Kalan MANUEL adımlar (senin ortamında / mağaza panellerinde)

Bunların hiçbiri buradan yapılamaz: SDK, keystore veya mağaza girişi gerektirir.

**Kod / build**
1. `flutter pub get && flutter analyze && flutter test` — temiz olmalı
   (`analyze` uyarısı build'i kırmaz; yalnızca *error* kırar).
2. `build_release.sh` içindeki `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`'i
   doldur → `./build_release.sh`. (Guard, eksik bırakırsan durdurur.)
   Çıktı: `build/app/outputs/bundle/release/app-release.aab`.
3. Keystore'u doğrula:
   `keytool -list -v -keystore /Users/tekiz/rutin-release.jks -alias rutin`
   → "Alias name: rutin" + "PrivateKeyEntry" görmelisin. **Keystore'u yedekle**;
   kaybı = uygulamayı bir daha güncelleyememek.

**Supabase** (`config.toml` bu tur eklendi → deploy artık bu klasörden çalışır)
4. `supabase login && supabase link --project-ref <PROJE_REF>`
   sonra `supabase functions deploy verify-receipt`
   (`config.toml` `verify_jwt=false` içerdiği için `--no-verify-jwt` gerekmez).
5. `supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='...' GOOGLE_PACKAGE_NAME=com.alper.rutin APPLE_SHARED_SECRET='...'`
6. SQL Editor'de `supabase_delete_user.sql`'i çalıştır (**"Hesabı Sil" bunu
   çağırıyor, zorunlu**). Sosyal katman kullanacaksan `supabase_schema.sql` de.

**AdMob (admob.google.com)**
7. App ID'leri (`~4926851592` Android, `~9045016421` iOS) ve banner birimlerini
   (`/9987606580`, `/8538793547`) kendi hesabından teyit et — config'te doğru görünüyor.

**Google Play Console**
8. `com.alper.rutin` uygulamasını oluştur, `.aab`'yi yükle.
9. Abonelikleri birebir tanımla: `rutin_pro_monthly`, `rutin_pro_yearly`.
10. Android Publisher API için servis hesabı → Play'e bağla → JSON'u (5)'e ver.
11. Veri Güvenliği formu + Hesap Silme beyanı + Gizlilik Politikası URL'i
    (`gizlilik-politikasi.md`'i yayınla).

**App Store Connect**
12. Aynı ID'lerle abonelikleri tanımla: `rutin_pro_monthly`, `rutin_pro_yearly`.
13. App-Specific Shared Secret al → (5)'teki `APPLE_SHARED_SECRET`.
14. App Privacy formu ("Data Used to Track You" — reklam + ATT).
15. Xcode'da imzalama/provisioning → `flutter build ipa --release` → archive/upload.

---

## 4. Kalan riskler

| Risk | Seviye | Not |
|---|---|---|
| `verify-receipt` deploy/secret eksik → her satın alma `valid:false`, Pro açılmaz | **Yüksek** | Deploy + 3 secret zorunlu (§3.4–3.5). Kod hazır, deploy manuel |
| `delete_user` SQL kurulmazsa "Hesabı Sil" sunucu hesabını silemez | **Orta** | Kod çağırıyor; SQL'i çalıştır (§3.6). Ağ/RPC yoksa yerel silme yine çalışır |
| Keystore doğrulanamadı (ortam dışı) | **Orta** | §3.3'teki `keytool` komutunu çalıştır + yedekle |
| `test`/`analyze`/build burada çalıştırılamadı (SDK yok) | **Orta** | Statik doğrulandı; nihai teyit sende (§3.1–3.2) |
| Test reklamı / bozuk Supabase ile release | ~~Yüksek~~ **Düşük** | Bu turda eklenen guard artık bunu build zamanında durduruyor |
| AGP/Kotlin/Gradle sürümleri güncel Flutter (3.29+) gerektirir | **Düşük** | 2026 için makul; bir kez build ederek uyumu teyit et |
| Sosyal şema (`supabase_schema.sql`) v1'de kullanılmıyor | **Düşük** | Sosyal özellik yoksa opsiyonel |

---

## 5. Değişen dosyalar

- `supabase/config.toml` — **YENİ (bu tur)**: deploy enabler + `verify-receipt`
  için `verify_jwt=false`.
- `build_release.sh` — placeholder preflight guard (önceki tur).
- `lib/auth.dart`, `lib/store.dart` — sunucu tarafı hesap silme (önceki tur).

Bu turda yalnızca `supabase/config.toml` eklendi; başka hiçbir dosya
değiştirilmedi. App davranışı, UI ve Dart kodu aynı.

---

## 6. 2. tur doğrulama özeti (bu oturum)

Tüm iddialar bağlı klasördeki gerçek dosyalara karşı yeniden denetlendi:

- **İmza:** `android/app/build.gradle.kts` → `signingConfigs.release` doğru
  `key.properties`'e bağlı; `keyAlias=rutin`, `storeFile=/Users/tekiz/rutin-release.jks`.
  Keystore dosyası bağlı klasör dışında → burada `keytool` ile doğrulanamadı (§3.3 manuel).
- **Import bütünlüğü:** tüm 30+ Dart dosyasının relative import'ları programatik
  tarandı → **kırık referans yok**. `settings_screen.dart → screens/themes_screen.dart
  → ui/paywall_screen.dart` zinciri sağlam.
- **AdMob:** Android app `~4926851592`, iOS app `~9045016421` (aynı hesap
  `...2837265476679803`); TEST ID'leri yalnızca kod içi fallback default.
- **IAP sözleşmesi:** `iap.dart` yalnızca `statusCode==200 && body['valid']==true`
  ile Pro açıyor; `verifyReceiptUrl` `main.dart`'ta `SUPABASE_URL`'den türetiliyor.
  Fonksiyonun döndürdüğü şekil ({valid}) istemciyle uyumlu.
- **Test:** `widget_test.dart`'ın kullandığı semboller (`Streak.fromJson`,
  `daysOrBest`, `TaskItem.activeOn`, `greetingFor`) `models.dart`/`home_logic.dart`'ta
  mevcut ve imza uyumlu.

Değişmeyen tek eksik: `flutter analyze`/`test`/`.aab` ve keystore doğrulaması bu
ortamda SDK/dosya olmadığından çalıştırılamadı → senin makinende (§3).
