# Faz 4 — Uygulama Günlüğü

Her satır: bulgu → değişiklik → doğrulama sonucu. Baseline: analiz 0/0, test 60/60.

---

## [BUG-001] P1 · bugs · Arka plan izolatında korumasız cast

**Sorun:** `lib/home_widget_service.dart:148` — `item as Map<String, dynamic>` çıplak cast.
`jsonDecode` try ile korunuyordu ama dizinin ELEMANLARI üzerindeki cast korunmuyordu.
Kanıtın gücü: aynı dosyanın 112. satırında aynı desen tip kontrollü yazılmıştı.

**Etki:** `backgroundCallback` ayrı bir Flutter izolatında çalışır, üstünde yakalayıcı yoktur.
Bozuk tek bir eleman TypeError fırlatıyor, widget dokunuşu sessizce işlenmiyordu.

**Yaklaşım:** Saf mantık `toggleWidgetTasks` fonksiyonuna çıkarıldı (platform kanalına
dokunmaz → doğrudan test edilebilir). Önce başarısız test yazıldı.

**Testin uygulamayı iki kez değiştirdiği nokta — asıl kazanç burada:**

1. İlk deneme `is Map` kontrolüydü. Test, dar değer tipli haritada (`Map<String, int>`)
   `item['done'] = true` yazarken TypeError aldığını gösterdi.
2. İkinci deneme kontrolü `is Map<String, dynamic>`e daralttı. Test yine kırmızı kaldı:
   **Dart'ta jenerikler kovaryant**, `Map<String, int>` bu kontrolden de geçiyor.
3. Doğru çözüm tip kontrolü değil, **girdiyi yerinde değiştirmemek** oldu. Her harita
   gevşek tipli bir kopyaya alınıyor; sözleşme artık tipten bağımsız olarak geçerli.

Testi geçirmek için test gevşetilmedi; test, uygulamanın yanlış olduğunu iki kez kanıtladı.

**Değişiklik:**
- `lib/home_widget_service.dart` — `toggleWidgetTasks` eklendi, `backgroundCallback` ona bağlandı
- `test/home_widget_test.dart` (yeni) — 6 test

**Doğrulama:**
- `flutter test test/home_widget_test.dart` → önce kırmızı (fonksiyon yok) → **6/6 yeşil**
- `flutter test` → **66/66** (öncesi 60/60, +6)
- `flutter analyze --fatal-warnings` → **0 hata / 0 uyarı**
- Regresyon: `toggleWidgetTasks` yalnızca `backgroundCallback` + testlerden çağrılıyor;
  `rutin_widget_summary` formatı (`X/Y`) satır 84 ve 192'de ve Kotlin okuyucusunda tutarlı

**Durum:** ✅ Düzeltildi

---

## [ARCH-001] P2 · quality · Paylaşılan bileşen ekran dosyasından UI kit'e taşındı

**Sorun:** `rutinAppBar` `lib/ui/water_screen.dart:329`'da tanımlıydı ve 8 ekran
(paywall, ayarlar, arkadaşlar, rozetler, haftalık rapor, içgörüler, mektup, iyileşme
zaman çizelgesi) yalnızca bunu alabilmek için su takip ekranını import ediyordu.
Satın alma ekranı, su ekranının tüm bağımlılıklarını sürüklüyordu.

**Ön kontrol (önemli):** 10 dosya `water_screen.dart` import ediyordu, ama ikisi
(`profile_screen.dart:15`, `home_screen.dart:14`) `show` KULLANMIYORDU — onlar
`WaterScreen`'in kendisini navigasyon için kullanıyor. Bu ikisine dokunulmadı.
Sekizinin hepsi `rutin_ui.dart`'ı zaten import ediyordu, yani taşıma sonrası
ek import gerekmedi.

**Değişiklik:**
- `lib/ui/rutin_ui.dart` — `rutinAppBar` eklendi (tek tanım)
- `lib/ui/water_screen.dart` — `_appBar` + dışa açma satırı kaldırıldı (24 satır),
  kendi kullanımı `rutinAppBar`'a çevrildi
- 8 ekrandan `import 'water_screen.dart' show rutinAppBar;` kaldırıldı

**Doğrulama:**
- `flutter analyze --fatal-warnings` → **0 hata / 0 uyarı**
- `flutter test` → **66/66**
- Regresyon: `rutinAppBar` tanımı tek yerde (`rutin_ui.dart:678`); kullanan 9 ekranın
  hepsi derleniyor; `water_screen.dart` fan-in **8+2 → 2**'ye düştü ve kalan ikisi
  gerçekten `WaterScreen` kullananlar

**Durum:** ✅ Düzeltildi

---

## [QUAL-004] P3 · quality · Tek kalan ekran eski klasörden taşındı

**Sorun:** `lib/screens/themes_screen.dart` tek başına eski klasör düzeninde kalmıştı;
diğer 20 ekran `lib/ui/` altında. Refactor sırasında atlanmış.

**Değişiklik:** `git mv` ile `lib/ui/themes_screen.dart`'a taşındı (geçmiş korundu).
Yol referansları düzeltildi:
- Taşınan dosyada `'../ui/paywall_screen.dart'` → `'paywall_screen.dart'`
- `settings_screen.dart:15` `'../screens/themes_screen.dart'` → `'themes_screen.dart'`
- Boşalan `lib/screens/` kaldırıldı

**Doğrulama:** `flutter analyze --fatal-warnings` → 0/0 · `flutter test` → 66/66

**Durum:** ✅ Düzeltildi

---

## [QUAL-003] P3 · quality · Kullanılmayan RError, silinmek yerine benimsendi

**Sorun:** `lib/ui/rutin_ui.dart:569` — `RError` tanımlıydı ama hiçbir yerden
çağrılmıyordu (ölü kod).

**Neden silinmedi:** Kodu okurken şu ortaya çıktı — `paywall_screen.dart:414`'te
`RError`'ın yaptığı şey **elle tekrarlanmıştı**: aynı `cloud_off_rounded` ikonu,
aynı "Tekrar Dene" etiketi, aynı yapı. Yani bileşen ölü değildi, sadece
kullanılması gereken yerde kullanılmamıştı. Silmek tekrarı kalıcı hale getirirdi.

**Değişiklik:** `lib/ui/paywall_screen.dart` — elle kurulan `REmpty(...)` bloğu
`RError(title:, message:, onRetry:)` ile değiştirildi. Görsel çıktı birebir aynı
(RError zaten REmpty'ye delege ediyor), tekrar ortadan kalktı.

**Doğrulama:** `flutter analyze --fatal-warnings` → 0/0 · `flutter test` → 66/66

**Durum:** ✅ Düzeltildi

---

## [ARCH-003] P3 · quality · UYGULANMADI (gerekçeli)

**Bulgu:** `lib/main_ui.dart:11` yalnızca `main.dart`'ın `main()`'ini çağıran
mükerrer giriş noktası.

**Neden uygulanmadı:** Kaldırmadan önce referans taraması yapıldı ve dosyanın
**dokümante edilmiş bir çalıştırma hedefi** olduğu görüldü:

- `RELEASE-CHECKLIST.md:165` — "`main_ui.dart`'ı bir kez çalıştırıp doğrula"
- `RELEASE-CHECKLIST.md:180` — `flutter run -t lib/main_ui.dart`

Silmek, dokümante edilmiş bir komutu sıfır işlevsel kazanç karşılığında bozar.
Faz 0'daki "bilmiyorsan sor / kapsam sızması yasak" kuralları gereği
uygulanmadı; öneri olarak kalıyor.

**Öneri:** Dosya kaldırılacaksa `RELEASE-CHECKLIST.md`'deki üç referans da
aynı commit'te güncellenmeli. Bu bir ürün/süreç kararıdır.

**Durum:** ⏸️ Uygulanmadı — gerekçe yukarıda

---

## [DEVOPS-002 + DEVOPS-003] P2/P3 · devops · CI kapsamı genişletildi

**Sorun 1 (DEVOPS-002):** Pipeline yalnızca analiz, test ve **Android** debug
derlemesi yapıyordu. Uygulama iOS'ta yayınlanıyor; iOS tarafını kıran bir
değişiklik (Info.plist, entitlement, Podfile, platform kanalı kullanan Dart kodu)
CI'dan **yeşil geçiyordu**. Ayrıca bağımlılık borcu hiçbir yerde görünmüyordu.

**Sorun 2 (DEVOPS-003):** `push` tetikleyicisi yalnızca `[main, theme-update]`
dallarını kapsıyordu; özellik/denetim dallarına yapılan pushlar CI çalıştırmıyordu.
(`theme-update` zaten main'e birleştirilmişti.)

**Değişiklik — `.github/workflows/ci.yml`:**
- `push` dal filtresi kaldırıldı; tüm dallar CI çalıştırıyor. Maliyet, mevcut
  `concurrency: cancel-in-progress` bloğu sayesinde sınırlı.
- Yeni iş: **`build-ios`** (macos-latest, `needs: analyze-and-test`) →
  `flutter build ios --debug --no-codesign`
- Yeni adım: **bağımlılık raporu** (`flutter pub outdated`), build'i KIRMAZ —
  amaç 21 eski paket + KGP borcunu görünür tutmak, yükseltme kararını insana
  bırakmak
- Başlıktaki bayat test sayısı düzeltildi (38 → 66)

**Doğrulama:**
- YAML sözdizimi doğrulandı → 3 iş: `analyze-and-test`, `build-android`, `build-ios`
- **CI'a eklenen iOS komutu YERELDE çalıştırıldı:** `flutter build ios --debug
  --no-codesign` → `✓ Built build/ios/iphoneos/Runner.app` (64,9s).
  Çalıştırmadan commit'lenmedi.
- `flutter analyze` → 0/0 · `flutter test` → 66/66

**Not:** `build-ios` işi macOS runner kullanır. Public repo'da GitHub Actions
dakikaları ücretsizdir (dosyanın kendi başlığında da yazıyor), ancak repo bir gün
private yapılırsa macOS dakikaları Linux'un 10 katı sayılır — o durumda bu işin
yalnızca `main` ve PR'larda çalışacak şekilde daraltılması gerekebilir.

**Durum:** ✅ Düzeltildi

---

## [DEVOPS-004] P2 · devops · Çevrimdışılık artık olay değil, iz (breadcrumb)

**Kaynak:** Faz 4 sırasında kullanıcının ilettiği canlı Sentry olayı.

```
ClientException with SocketException: Failed host lookup:
'pfgljdvkmkqvlvdljvjk.supabase.co' (OS Error: No address associated
with hostname, errno = 7)
  → postgrest_builder.dart _executeWithRetry
  → op: cloud_load  (lib/repository.dart:125)
```

**Bu bir hata DEĞİL.** `errno = 7` DNS çözülememesi, yani cihaz çevrimdışı.
Uygulama bunu zaten doğru işliyor: yerel önbelleğe düşüyor, veri güvende,
kullanıcıya `AppState.dataUnavailable` şeridiyle bilgi veriliyor.

**Sorun gözlemlenebilirlikte:** Metroya giren tek bir kullanıcı her okuma/yazma
denemesinde bir Sentry olayı üretiyordu. Bu gürültü, gerçek arızaları (satın
alma doğrulaması patlaması, veri bozulması) görünmez hale getirir. Olay
toplamak amaç değil; sinyali korumak amaç.

**Değişiklik — `lib/diagnostics.dart`:**
- `isOfflineError()` eklendi; çevrimdışı hatalar `Sentry.addBreadcrumb` ile
  **iz** olarak kaydediliyor, olay üretilmiyor
- Tamamen yok sayılmıyor: sonradan gerçek bir hata raporlanırsa izlerde
  "o sırada ağ yoktu" görünür ve teşhisi kolaylaştırır

**İki bilinçli karar:**
1. **`TimeoutException` hariç tutuldu.** Açılış adımı zaman aşımları
   (`boot_step` etiketi, Sentry'de 20 olay) gerçek bir teşhis sinyali —
   çevrimdışılık değil. Onu susturmak aradığımız bilgiyi yok ederdi.
2. **`dart:io`'ya bağlanılmadı** (`error is SocketException` yazılamadı):
   proje web'i de hedefliyor, orada `dart:io` derlenmez. Tip yerine mesaj
   eşleştirmesi yapıldı — kırılgan ama taşınabilir; ödünleşim yorumda yazılı.

**Doğrulama:**
- 5 yeni test — sahadan gelen **gerçek olay metniyle** birebir
- `TimeoutException` ve gerçek uygulama hatalarının filtrelenMEdiği ayrıca test edildi
- `flutter analyze --fatal-warnings` → **0 hata / 0 uyarı / 0 info**
- `flutter test` → **71/71** (öncesi 66)
- Regresyon: 13 `op` etiketinin tamamı çalışır durumda

**Durum:** ✅ Düzeltildi
