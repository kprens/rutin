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

---

## [TEST-001] P1 · tests · Kritik yollara hedefli test

**Sorun:** Kapsam %20,3 (375/1845). Bu soyut bir metrik değildi — bu oturumda tam
bu boşluktan doğan iki gerçek hata bulundu (paywall çıkmazı, `home_logic`'in
üretimde hiç çağrılmaması), üstelik testler yeşilken.

**Yaklaşım:** Kapsam yüzdesini kovalamak yerine, **gerçekten para/veri kaybettiren
üç yola** test yazıldı.

### 1. `dailyRollover` 400 günlük budama (4 test)

Bu fonksiyon kullanıcının GEÇMİŞİNİ siliyor. Sıralama ters olsaydı en yeni veri
silinir, en eskisi kalırdı — sessiz bir hata, kullanıcı ancak aylar sonra fark
eder. Test edilmiyordu. Artık kilitli: 400 altında hiçbir şey silinmiyor, üstünde
**en eskiler** gidiyor, bugünün kaydı asla silinmiyor. `doneByDate`, `waterByDate`
ve `waterLog` ayrı ayrı doğrulandı.

### 2. Aylık ürün kimliği çözümleme (5 test)

Bu oturumun en pahalı hatası: App Store Connect'te aylık aboneliğin Product ID'si
sonunda **nokta** ile oluşturulmuştu (`rutin_pro_monthly_v2.`). Kod noktasızı
arıyordu; paywall'ın `ready` koşulu ikisini birden şart koştuğu için ekran
tamamen kilitleniyordu — yıllık gelse bile. Günlerce hiç kimse abonelik satın
alamadı.

Test yazabilmek için mantık saf bir fonksiyona çıkarıldı
(`Iap.resolveMonthly(storeIds, isIos:, fallback:)`) — platform ve ağ bağımlılığı
yok. Kapsanan davranışlar: noktalı seçilir, noktasız seçilir (ürün ileride düzgün
kimlikle yeniden oluşturulursa kod kendiliğinden geçer), hiçbiri tanınmıyorsa
fallback korunur, Android kendi kimliğini kullanır, ikisi de dönerse öncelik
sırası.

### 3. Çevrimdışı filtre (5 test — DEVOPS-004 ile birlikte)

Sahadan gelen gerçek olay metniyle.

**Doğrulama:**
- `flutter test` → **80/80** (baseline 60/60, **+20 test**)
- `flutter analyze --fatal-warnings` → **0 hata / 0 uyarı / 0 info**
- Kapsam: **%20,3 → %23,3** (375/1845 → 438/1882)

**Dürüst değerlendirme:** %23,3 hâlâ düşük ve bu iş bitmedi. Ama eklenen 20 test
rastgele satır kapsamı değil; ikisi bu oturumda gerçekten yaşanmış, biri para
kaybettiren hataları kilitliyor. Ekran/widget testleri ve satın alma akışının
uçtan uca testi hâlâ yok — Faz 6'da kalan risk olarak raporlanacak.

**Durum:** ✅ Uygulandı (süregiden iş olarak devam etmeli)

---

## SAHA VERİSİ TRİYAJI — Sentry (2026-07-31)

Sentry API'ye salt-okunur token ile bağlanıldı; 8 açık kayıt tek tek incelendi.
Bu bölümün değeri, denetimin varsayım yerine **sahadan gelen kanıtla**
çalışabilmesi: iki teori çürütüldü, bir gerçek çökme bulundu.

### Canlı olan (build 17'de aktif)

| Kayıt | Başlık | Olay/Kullanıcı | Durum |
|---|---|---|---|
| RUTIN-4 | Mağaza hiç ürün döndürmedi | 21 / 13 | Açık — mağaza tarafı |
| RUTIN-8 | Mağaza katmanı kullanılamıyor (isAvailable=false) | 1 / 1 | Açık — RUTIN-4 ile aynı cihaz |

### Kapatılabilir (kod düzeltmesi sonrası hiç görülmedi)

| Kayıt | Son görülen build | Neden ölü |
|---|---|---|
| RUTIN-1 | 8 | Bildirim ikonu kaynağı eklendi |
| RUTIN-2 | 10 | Bildirim ikonu kaynağı eklendi |
| RUTIN-3 | 13 | Açılış zaman aşımı; 8sn'lik zincir kırıldı |
| RUTIN-5 | 14 | 5sn zaman aşımı |
| RUTIN-7 | 13 | Çevrimdışı DNS — artık breadcrumb, olay değil |
| RUTIN-6 | 13 | **Bu oturumda kökten düzeltildi** (aşağıda) |

> Token salt-okunur (`event:write` kapsamı yok), bu yüzden kayıtlar Sentry
> panelinden elle kapatılmalı. Nüksederse Sentry regresyon olarak yeniden açar.

### Çürütülen teori: RUTIN-4 bir ürün kimliği sorunu DEĞİL

Aylık aboneliğin App Store'daki sondaki noktası (`rutin_pro_monthly_v2.`)
2.1(b) reddinin sebebiydi ve düzeltildi — ama RUTIN-4'ün sebebi o değil.
`notFound` etiketi her olayda sorulan kimliklerin **tamamını** içeriyor:

```
Android 19/21 : rutin_pro_monthly, rutin_pro_yearly, rutin_pro_lifetime
iOS       2/21 : rutin_pro_monthly_v2, rutin_pro_yearly, rutin_pro_lifetime
```

Listede `rutin_pro_yearly` de var — satın alma testi yapılmış, çalıştığı
bilinen ürün. Tek bir kimliğin yazımı bunu açıklayamaz; mağaza sorulan
**hiçbir** ürünü tanımıyor.

Ölçek de sanıldığından küçük: 19 Android olayının tamamı **tek bir cihaz
modelinden** (OnePlus 8 Pro) geliyor. 13 "kullanıcı" bu tek modele sıkışmış —
mağazaya hiç erişemeyen bir test/lab cihazı profili.

`iap_no_products` olayına `queried` ve `allMissing` etiketleri eklendi
([lib/iap.dart](../lib/iap.dart)); build 18'den itibaren "mağaza sorulan her
şeyi reddetti" ile "bazılarını tanıdı ama liste boş" ayrımı doğrudan okunacak.

### Bulunan gerçek çökme: RUTIN-6 (ölümcül, Android 16)

Bu kayıt "eski" görünüyordu çünkü yalnızca build 13'te vardı — ama düzeldiği
için değil, o cihazdaki tek kullanıcı güncellemediği için.

```
RuntimeException: Unable to start receiver HabitWidgetProvider
→ IllegalArgumentException: pendingIntentBackgroundActivityStartMode
  must not be set when creating a PendingIntent
```

Kök neden bizim kodumuzda değil, `home_widget` 0.6.0'da: `HomeWidgetIntent.kt`
SDK 34+ için PendingIntent'i `pendingIntentBackgroundActivityStartMode` ile
oluşturuyor ve SDK 35 ayrımı yapmıyor. Android 15+ bu alanın **oluşturma**
anında verilmesini reddediyor.

Zaman çizelgesi önemli — ara düzeltme yeterli sanılabilirdi:

- **build 13** → try/catch yoktu, uygulama ölümcül çöküyordu
- **build 14/17** → try/catch eklendi, çökme durdu **ama** istisna
  `updateAppWidget`'tan önce atıldığı için widget Android 15/16'da sessizce
  hiç çizilmiyordu — yani özellik ölüydü, gürültüsüzce
- **build 18** → paket yükseltildi, widget güncel Android'de gerçekten çalışıyor

### Sürüm seçimi: neden 0.9.3 değil de 0.7.0+1

İlk yükseltme `^0.9.3`'e yapıldı; analiz, 104 test ve APK yeşil geçti — ama
`flutter build ios` **başarısız** oldu: 0.9.3 iOS 14 asgarisi istiyor,
uygulamanın hedefi iOS 13.

Değişiklik günlüğü taranarak çökmeyi düzelten **en erken** sürüm bulundu:
`0.7.0+1` — *"FIX: Runtime error when starting App from Widget on Android 15
(#330)"*. Kaynak doğrulandı: `SDK_INT >= 35` dalı 0.9.3'tekiyle birebir aynı.
0.7.0'ın kırıcı değişikliği yok; iOS asgarisi 11'de kalıyor.

iOS asgari sürümünü 14'e çekmek ayrı ve kullanıcıya dokunan bir karar —
gönderim sırasında değil, bilinçli olarak alınmalı.

### RUTIN-6 çalışma zamanı doğrulaması (emülatör, API 37 / Android 17)

Kaynak karşılaştırması tek başına yeterli sayılmadı; düzeltme gerçek bir
Android 15+ cihazda çalıştırılarak doğrulandı.

**Neden zor:** `onUpdate` içindeki try/catch istisnayı yutuyor, bu yüzden
"logcat temiz" tek başına kanıt değil. Ayırt edici gözlem, widget'ın
**çizilip çizilmediği**.

**Yöntem:**
1. `app-debug.apk` API 37 emülatöre kuruldu, widget ana ekrana eklendi
2. Widget verisi `run-as` ile doğrudan `HomeWidgetPreferences.xml`'e yazıldı
   (hesap açmadan test edebilmek için)
3. `am broadcast APPWIDGET_UPDATE` ile `onUpdate` tetiklendi

**Sonuç:**

| Aşama | Widget görünümü |
|---|---|
| Süreç öldürülmüş, güncelleme yok | Gri yer tutucu (uygulama ikonu) |
| `onUpdate` tetiklendikten sonra | "Bugün" başlığı + özet `0/0` |

Başlık (`android:text="Bugün"`) layout'ta sabit olduğu için kanıt sayılmadı.
Belirleyici olan **özet satırı**: layout varsayılanı `android:text=""` ve bu
alanı yalnızca `renderWidget` dolduruyor — üstelik çöken
`HomeWidgetLaunchIntent.getActivity` çağrısından SONRA gelen
`appWidgetManager.updateAppWidget` ile. Özetin ekrana düşmesi, `renderWidget`
fonksiyonunun API 37'de baştan sona çalıştığını gösteriyor.

logcat'te `FATAL`, `Unable to start receiver`, `IllegalArgumentException`
kaydı yok.

---

## TEST-002 — Uygulamayı gerçekten çalıştıran test katmanları (2026-07-31)

**Boşluk:** 104 test vardı, hepsi saf mantık. `main()` ve widget ağacı hiçbir
otomasyonda bir kez bile çalışmıyordu; CI yalnızca derliyordu. Derlenen bir
uygulamanın açılmadan çökmesi mümkün ve bu sahada defalarca yaşandı.

Yaşanan retlerin/çökmelerin hangisini hangi katman yakalar:

| Olay | Birim testi | Duman testi | Entegrasyon |
|---|---|---|---|
| Paywall kilidi (2.1(b) reddi) | kısmen | ✅ | ✅ |
| Bildirim ikonu (RUTIN-1/2) | ✗ | ✗ | ✅ |
| Açılışta istisna | ✗ | ✅ | ✅ |
| iPad genişlik sınırı (Guideline 4) | ✗ | ✅ | ✅ |
| Widget çökmesi (RUTIN-6) | ✗ | ✗ | ✗ (Play Pre-Launch) |

### Katman 1 — `test/smoke_test.dart` (8 test, emülatörsüz)

Widget ağacını gerçekten kurup çizer. En zor kısım mağaza katmanıydı:
`InAppPurchase.instance` ilk erişimde Play Billing'e bağlanmaya çalışıp
ASENKRON patlıyor ve hata "test bittikten sonra" yüzeye çıkıp alakasız bir
testi düşürüyordu.

Kanal taklidi (pigeon codec'ine bağımlı, kırılgan) yerine eklentinin kendi
genişletme noktası kullanıldı: hedef platform android/iOS DIŞINA çekilince
`_getOrCreateInstance` otomatik kayıt yapmıyor ve `InAppPurchasePlatform.instance`
dışarıdan atanabiliyor. Testler hiçbir platform kanalına dokunmuyor.

İki tuzak belgelendi, çünkü ikisi de "yeşil ama boş" test üretiyordu:
- Paywall bir `ListView` ve ListView TEMBEL — görünüm alanına girmeyen plan
  kartlarını hiç kurmuyor, `find` bulamıyordu.
- Widget testleri her karakteri tam kare çizen test yazı tipini kullanıyor;
  gerçekte taşmayan satırlar testte taşıyor.

### Katman 2 — `integration_test/app_boot_test.dart` (4 test, gerçek cihaz)

Katman 1'in göremediği yer: Dart ile native arası. Bildirim servisi kurulumu,
hatırlatma zamanlama, yerel depo, ilk kare.

### Mutasyon doğrulaması

Yeşil ama hiçbir şeyi korumayan test yazmamak için her iki katman da bilerek
bozularak sınandı:

| Geri konan hata | Sonuç |
|---|---|
| Paywall `ready` koşulu `\|\|` → `&&` | tam da doğru 2 duman testi düştü |
| Bildirim ikonu var olmayan kaynağa çevrildi | `PlatformException(invalid_icon, ...)` — RUTIN-1/2'nin birebir hatası — 2 entegrasyon testi düştü |

İkisi de geri alınınca 8/8 ve 4/4 geçti.

> Yan bulgu: ilk mutasyon denemesi (`@mipmap/` öneki) YAKALANMADI. Sebep
> testin zayıflığı değildi: ikon hem `mipmap-*` hem `drawable-*` altında
> duruyor ve Android'in `getIdentifier` çağrısı `@tür/ad` biçimini
> ayrıştırdığı için o önek bugün gerçekten çözülüyor. Test işe yaramıyor
> sanıp geçmek yerine sebep kovalandı.

### CI

`analyze-and-test` duman testlerini ayrıca ve AÇIKÇA koşuyor — dosya
silinir/yeniden adlandırılırsa build kırılsın diye; tek toplu koşuda sessizce
kaybolurdu. Yeni `integration-android` işi gerçek emülatörde (API 34, KVM
açık) entegrasyon testlerini çalıştırıyor.

**Doğrulama:** analyze temiz · 112/112 birim+duman · 4/4 entegrasyon (API 37).
