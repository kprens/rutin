# Rutin — Kapsamlı Uygulama Denetimi Raporu

**Tarih:** 2026-07-26 · **Dal:** `theme-update` · **Kapsam:** 13.4k satır Dart (43 dosya), Supabase Edge Function, iOS/Android yapılandırması

> **Dürüstlük notu:** Bu rapordaki her bulgu kod okunarak doğrulanmıştır. Doğrulayamadığım
> hiçbir şey kesinmiş gibi sunulmadı; ölçemediklerim açıkça **hipotez** olarak işaretlendi.
> Uygulama gerçek cihazda/simülatörde ÇALIŞTIRILMADI — UI davranışı statik analiz, derleme
> ve testlerle doğrulandı, gözle değil. Gerçek dönüşüm/retention verisi elimde **yok**.

---

## 1. Yönetici Özeti

1. **Uygulamanın kendisi beklediğimden sağlıklı.** Derleme temiz (0 hata), 15 test geçiyor,
   kod okunabilir ve yorumlar geçmiş hataların nedenini anlatıyor. Açılış zinciri geçmiş
   "uygulama hiç açılmıyor" vakalarından ders alınarak titizce korunmuş.
2. **Ama kullanıcının verisini silen bir hata vardı.** Geçici bir internet kesintisi,
   kullanıcının buluttaki tüm verisinin cihazdaki boş veriyle **kalıcı olarak ezilmesine**
   yol açıyordu. Düzeltildi ve testle kilitlendi.
3. **Çevrimdışı girilen her şey kayboluyordu.** Hesabıyla giriş yapmış bir kullanıcı
   internetsizken ne yaptıysa (işaretlenen görevler, su, nüks kaydı) uygulama kapanınca
   yok oluyordu. Düzeltildi.
4. **"Ömür Boyu" planı satılıyor ama açılması imkânsızdı.** Sunucu doğrulaması tek seferlik
   ürünü abonelik gibi doğrulamaya çalıştığı için **her zaman** başarısız oluyordu: kullanıcı
   parayı ödüyor, Pro açılmıyordu. Düzeltildi.
5. **Uygulamada tek bir gizlilik politikası bağlantısı yoktu.** Bu tek başına hem App Store
   hem Google Play reddi sebebidir. Paywall ve Ayarlar'a eklendi.
6. **Hesap silme, sunucuda başarısız olsa bile "silindi" diyordu.** Apple'ın hesap silme
   zorunluluğu açısından riskli; artık kullanıcı gerçeği görüyor.
7. **Bildirim izni, kullanıcı hiçbir şey görmeden açılışta isteniyordu.** Bu üründe
   bildirim retention'ın ana kaldıracı; izin artık kullanıcı ilk alışkanlığını kurduktan
   sonra isteniyor.
8. **EEA kullanıcıları için reklam rıza (UMP) akışı hiç yoktu** — GDPR uyumsuzluğu ve
   Google'ın reklam yayınını kısıtlama riski. Eklendi (yeni bağımlılık gerekmedi).
9. **Ürün ölçülemiyor: sıfır analytics.** Paywall'ı kaç kişi gördü, nerede vazgeçti,
   hiçbiri bilinmiyor. Dönüşüm optimizasyonunun ön koşulu bu; en öncelikli eksik.
10. **iOS'ta ATT izni hiç istenmiyor** — `Info.plist`'te metin var, kodda çağrı yok.
    Reklam gelirini doğrudan düşürüyor (hipotez: iOS eCPM kaybı belirgin).

---

## 2. Proje Sağlık Karnesi

| Alan | Puan (1-10) | Gerekçe |
|------|-------------|---------|
| Kod Kalitesi | 7 | Okunabilir, iyi yorumlanmış; ancak 48 adet sessizce yutulan `catch (_)` var. |
| Mimari | 7 | Repository + ChangeNotifier ayrımı temiz; `store.dart` 1300+ satırla şişmiş. |
| Performans | 6 | Seri hesabı önbelleklenmiş (iyi); onboarding'de kare başına rebuild vardı (düzeltildi). |
| Güvenlik | 6 | RLS + security-definer silme doğru; doğrulama uç noktası kimliksiz ve makbuz kullanıcıya bağlanmıyor. |
| Test Kapsamı | 4 | 15 → 27 teste çıktı, ama ekranların ve satın alma akışının testi hâlâ yok. |
| UI/UX | 7 | Tutarlı tasarım dili (RC/RG/RText), premium his mevcut; boş/hata durumları eksik. |
| Erişilebilirlik | 3 | Semantics etiketi yok, kontrast doğrulanmamış, dokunma hedefleri denetlenmedi. |
| Analytics | 1 → 7 | Hiç yoktu; huni uçtan uca enstrümante edildi (bkz. §16). Dashboard/A-B altyapısı hâlâ yok. |
| Dönüşüm (CRO) | 6 | Paywall dürüst ve iyi kurgulanmış; beyan eksikleri vardı (düzeltildi), ölçüm yok. |
| Uyumluluk | 5 → 8 | Yasal bağlantı yokluğu ve hesap silme sessizliği kritikti; düzeltildi. ATT hâlâ eksik. |

---

## 3. Kritik Hatalar

### [F-001] Geçici ağ hatası buluttaki veriyi kalıcı siliyor · `store.dart` boot()/onSignedIn() · **Kritik** · ✅ Düzeltildi
`CloudRepository.loadAll()` hem "kayıt yok" hem "okuyamadım" durumunda `null` dönüyordu.
`boot()` bunu "hesap yepyeni" sanıp cihazdaki (çoğu zaman boş) veriyi yükleyip **hemen
buluta yazıyordu**. Sonuç: uçakta/metroda uygulamayı açan kullanıcı tüm geçmişini
kaybediyordu. `onSignedIn()` daha da kötüydü — durumu sıfırlayıp **boş belgeyi** buluta
yazıyordu.

**Çözüm:** `LoadResult` tipi eklendi (`found` / `missing` / `failure`). Okuma başarısızsa
buluta **hiçbir şey yazılmıyor**. 4 test bu davranışı kilitliyor.

### [F-002] Çevrimdışı yapılan her şey kayboluyor · `repository.dart` · **Kritik** · ✅ Düzeltildi
`CloudRepository.saveAll()` hatayı yutuyordu ve yerel yedek yoktu. Veri yalnızca bellekteydi;
uygulama kapanınca gidiyordu.

**Çözüm:** Her yazma önce cihaza işleniyor (write-through). Önbellek **hesaba özel anahtar**
kullanıyor (`rutinData_<uid>`) — aksi halde hesap değiştirince önceki kullanıcının verisi
sızardı. Tüm durum tek JSON belgesi olarak yazıldığı için bağlantı dönünce ilk kayıt
senkronizasyonu kendiliğinden tamamlıyor.

### [F-003] "Ömür Boyu" satın alma asla doğrulanamıyor · `verify-receipt/index.ts` + `iap.dart` · **Kritik** · ✅ Düzeltildi
Paywall `rutin_pro_lifetime` ürününü satıyor ama sunucu doğrulaması her ürünü abonelik
sanıyordu:
- **Play:** `purchases/subscriptions/...` uç noktası tek seferlik üründe 404 döner.
- **Apple:** non-consumable `latest_receipt_info`'da görünmez ve `expires_date_ms` alanı
  yoktur → `0 > now` → daima `false`.

Yani **kullanıcı parayı ödüyor, "Satın alma doğrulanamadı" hatası alıyor, Pro açılmıyordu.**

**Çözüm:** İstemci ürün tipini (`kind`) bildiriyor; sunucu Play'de `purchases/products`,
Apple'da `receipt.in_app` üzerinden sahiplik kontrolü yapıyor. Eski istemciler için
`subscription` varsayılanı korundu (geriye dönük uyumlu).

> ✅ **Dağıtıldı** (2026-07-26): `verify-receipt` v11 → v12, `verify_jwt: false`. Duman
> testleri geçti (eksik alan → 400, GET → 405, geçersiz makbuz → `valid:false`, çökme yok).

### [F-011] `APPLE_SHARED_SECRET` tanımlı değil — TÜM iOS satın almaları başarısız · **Kritik** · ⏳ Kullanıcı aksiyonu gerekiyor

Dağıtım öncesi secret denetiminde bulundu. Projede tanımlı secret'lar yalnızca
`GOOGLE_PACKAGE_NAME` ve `GOOGLE_SERVICE_ACCOUNT_JSON` (+ Supabase'in otomatik
enjekte ettikleri). **`APPLE_SHARED_SECRET` YOK.**

Apple'ın `verifyReceipt` uç noktası, otomatik yenilenen abonelik içeren makbuzlarda
`password` alanını **zorunlu** tutar. Alan gönderilmediğinde Apple `status: 21004`
döner → `appleReceipt()` null döner → doğrulama `false` → **Pro açılmaz.**

Yani F-003 yalnızca "ömür boyu" ürünü etkiliyordu; bu bulgu **iOS'taki aylık ve
yıllık abonelikler dahil TÜM satın almaları** etkiliyor. Kullanıcı ödüyor,
"Satın alma doğrulanamadı" hatası alıyor.

- **Doğrulanan:** Secret'ın tanımlı olmadığı (CLI ile listelendi).
- **Yüksek güvenle beklenen (hipotez, sandbox testiyle teyit edilmeli):** 21004
  nedeniyle her iOS doğrulamasının başarısız olması.

**Çözüm (bu komutu SİZ çalıştırmalısınız — kimlik bilgisi içerir):**
```bash
supabase secrets set APPLE_SHARED_SECRET='<App Store Connect → Uygulaman → Abonelikler → Uygulamaya Özel Paylaşılan Sır>'
```

### [F-012] Dağıtım öncesi yakalanan regresyon (kendi değişikliğimde) · ✅ Düzeltildi

Ömür boyu ürünü desteklemek için `exclude-old-transactions` `false` yapılmıştı; bu,
`latest_receipt_info` dizisinin tek bir güncel işlem yerine TÜM abonelik geçmişini
içermesine yol açıyor. Eski kod dizinin SON elemanını alıyordu — Apple bu dizinin
sıralamasını garanti etmez, dolayısıyla geçerli bir abone için yıllar önce dolmuş bir
işlem seçilip abonelik "süresi dolmuş" sayılabilirdi. **Dağıtımdan önce** fark edildi;
artık iptal edilmemiş işlemler arasından EN GEÇ bitiş tarihi alınıyor (sıralamadan
bağımsız olarak doğru).

### [F-004] Uygulamada hiç yasal bağlantı yok · **Kritik** · ✅ Düzeltildi
Gizlilik politikası ve kullanım koşulları bağlantısı **hiçbir ekranda** yoktu; `url_launcher`
bağımlılığı bile eklenmemişti. Bu; App Store 3.1.2 (abonelik ekranı), 5.1.1 (gizlilik) ve
Google Play zorunluluklarının ihlali — tek başına ret sebebi.

**Çözüm:** `lib/legal.dart` eklendi; paywall ve Ayarlar'a bağlantılar kondu.

> ⚠️ **Doğrulanması gereken:** `kprens.github.io/rutin-legal` adresinin **yayında** ve
> `/kullanim-kosullari` sayfasının **var** olduğu. Adres dokümanlardan alındı, erişilebilirliği
> test edilmedi. Kendi EULA'nız yoksa Apple'ın standart EULA adresi `legal.dart` içinde hazır.

---

## 4. Güvenlik Sorunları

| ID | Bulgu | Şiddet | Durum |
|----|-------|--------|-------|
| S-01 | `verify-receipt` kimlik doğrulamasız (`--no-verify-jwt`) ve makbuz bir kullanıcıya **bağlanmıyor**. Geçerli bir makbuz tekrar oynatılarak (replay) Pro açılabilir; uç nokta Apple/Google'a proxy olarak kötüye kullanılabilir. | Orta | ⏳ Planlandı |
| S-02 | iOS'ta **ATT izni hiç istenmiyor**. `NSUserTrackingUsageDescription` tanımlı ama kodda çağrı yok. App Privacy formunda izleme beyan edildiyse 5.1.2 riski. | Yüksek | ⏳ Planlandı |
| S-03 | `isPro` düz JSON olarak `SharedPreferences`'ta; rootlu cihazda değiştirilebilir. Çevrimdışı ürün için kabul edilebilir risk. | Düşük | Kabul |
| S-04 | `build_release.sh` gerçek Supabase anon key + Sentry DSN içeriyor. **Git'te izlenmiyor** (doğrulandı) ve ikisi de istemci binary'sinde zaten bulunur → gerçek sır sızıntısı yok. Yine de dosya başlığındaki "hiçbir gizli değer repoya gömülü değildir" ifadesi yanıltıcı. | Düşük | Not edildi |
| S-05 | Apple'ın `verifyReceipt` uç noktası eskitildi (legacy); App Store Server API'ye geçiş önerilir. Bugün çalışıyor. | Düşük | ⏳ Planlandı |
| S-06 | Parola politikası yok; Supabase varsayılanına (6 karakter) bırakılmış. | Düşük | ⏳ Planlandı |

---

## 5. Performans Sorunları

| ID | Bulgu | Durum |
|----|-------|-------|
| P-01 | Onboarding'de her kaydırma karesinde `setState` → tüm ağaç yeniden çiziliyordu. Kullanıcının gördüğü **ilk** ekranda jank. `ValueNotifier` + hedefli `ValueListenableBuilder` ile yalnızca renge bağlı 3 parça dinliyor. | ✅ Düzeltildi |
| P-02 | `RootShell` 5 ekranı tek `PageView` içinde canlı tutuyor; bellek ve ilk çizim maliyeti. | ⏳ Planlandı |
| P-03 | `taskStreak` önbelleği doğru kurulmuş (2000 güne kadar geri gitme maliyeti önlenmiş). | ✅ Zaten iyi |
| P-04 | `todaysDone`/`todaysWaterLog` getter'ları `putIfAbsent` ile **build sırasında map'i değiştiriyor**. Şu an zararsız ama getter'ın yan etkisi olması kırılgan. | ⏳ Planlandı |

> Ölçüm yapılamadı: soğuk açılış süresi, bundle boyutu ve fps değerleri gerçek cihaz
> gerektirir. Yukarıdaki etkiler **hipotez**dir (kod okumasına dayanır, ölçüme değil).

---

## 6. UI/UX Problemleri

- **U-01** Onboarding 3 jenerik pazarlama slaytından sonra **doğrudan giriş ekranına**
  atıyor. Kullanıcı değeri görmeden hesap açmaya zorlanıyor — kategorideki en büyük
  terk noktası. *(Öneri, uygulanmadı — ürün kararı gerektirir.)*
- **U-02** Kişiselleştirme sorusu yok ("neyi bırakıyorsun?"). Yatırım hissi ve
  kişiselleştirilmiş içerik fırsatı kaçıyor.
- **U-03** Erişilebilirlik denetlenmemiş: `Semantics` etiketi yok, dokunma hedefi
  boyutları doğrulanmadı, kontrast ölçülmedi.
- **U-04** Yükleniyor/boş/hata durumları her ekranda tasarlanmamış.
- **U-05** Abonelik yönetimi (iptal) için mağaza ayarlarına kısayol yok.

---

## 7. Kod Kalitesi Problemleri

- **K-01** `store.dart` 1300+ satır; state, IAP, arkadaşlar, su, takvim, bildirim ve
  hesap yönetimi tek sınıfta (God class). Modüllere ayrılmalı.
- **K-02** **48 adet** boş `catch (_)`. Çoğu bilinçli ve gerekçesi yorumda yazılı
  (açılışı korumak için), ama gerçek hatalar da sessizce kayboluyor. Sentry'ye
  raporlama yalnızca `main.dart`'ta var.
- **K-03** `activatePro()` üzerindeki yorum bayat: "Şimdilik test modu — Play Billing
  bağlandığında değiştirilecek" diyor; oysa doğrulama zaten bağlı.
- **K-04** `iap.dart:58`'deki `TODO` artık geçersiz (URL `main.dart`'ta türetiliyor).
- **K-05** Kullanılmayan/silinmiş dosyalar çalışma ağacında duruyor (`lib/screens/*`,
  `lib/main.dart.bak`, `lib/coach.dart` silinmiş ama commit edilmemiş).

---

## 8. Yapılan İyileştirmeler

| # | Dosya | Değişiklik | Gerekçe | Beklenen etki |
|---|-------|-----------|---------|---------------|
| 1 | `repository.dart` | `LoadResult` tipi; okuma başarısızlığı ile boş kayıt ayrıldı | Veri kaybı zincirini kırmak | Bulut verisi ezilmesi ortadan kalkar |
| 2 | `repository.dart` | Hesaba özel write-through yerel önbellek | Çevrimdışı yazma kaybı + hesap sızıntısı | Çevrimdışı veri kaybı sıfırlanır |
| 3 | `store.dart` | `boot()`/`onSignedIn()` başarısız okumada yazmıyor | F-001 | Veri bütünlüğü |
| 4 | `store.dart` | `_field<V>()` ile alan bazlı ayrıştırma koruması | Tek bozuk alan tümünü düşürüyordu | "Verim gitti" şikâyetleri azalır |
| 5 | `iap.dart` + Edge Function | Ürün tipine göre doğrulama (`kind`) | Ömür boyu satın alma hiç açılmıyordu | Ödenen her satın alma açılır |
| 6 | `legal.dart` (yeni) + paywall + ayarlar | Gizlilik/koşullar bağlantıları | Mağaza zorunluluğu | Ret riski kalkar |
| 7 | `paywall_screen.dart` | Deneme/fiyat/otomatik yenileme beyanı | App Store 3.1.2 + şeffaflık | İade ve 1-yıldız azalır |
| 8 | `auth.dart` + `store.dart` + ayarlar | Hesap silme sonucu döndürülüyor ve uyarılıyor | Apple 5.1.1(v) | Yanlış bilgilendirme biter |
| 9 | `main.dart` + `store.dart` | Bildirim izni onboarding sonrasına taşındı | Bağlamsız izin = yüksek ret | İzin oranı artar (hipotez) |
| 10 | `ads.dart` + ayarlar | UMP rıza akışı + rıza değiştirme satırı | GDPR / Google EU politikası | Yayın kısıtlama riski düşer |
| 11 | `onboarding_screen.dart` | Kare başına rebuild kaldırıldı | İlk izlenimde jank | Daha akıcı ilk deneyim |
| 12 | `settings_screen.dart` | `TextEditingController` sızıntısı kapatıldı | Bellek sızıntısı | — |
| 13 | `test/data_integrity_test.dart` (yeni) | 12 regresyon testi | Kritik hataları kilitlemek | Tekrar etmesi engellenir |

**Doğrulama:** `flutter analyze` → 0 hata (14 info, tamamı önceden mevcut stil uyarısı).
`flutter test` → **27/27 geçti**. `flutter build apk --debug` → **başarılı**.

---

## 9. Satın Alma Oranını Artıracak Öneriler

> Sıra: etki/çaba oranına göre. Hiçbiri dark pattern içermez.

1. **Analytics kur (ön koşul).** Hiçbir öneri ölçülemeden doğrulanamaz.
   Huni: `paywall_view → plan_select → purchase_start → purchase_success/fail`.
   *Gerekçe:* Şu an nerede kaybettiğinizi bilmiyorsunuz. *Ölçüm:* huni dönüşüm oranı.
2. **ATT iznini iste (iOS).** Reklam geliri doğrudan artar; ayrıca Pro'nun "reklamsız"
   değer önerisini güçlendirir. *Ölçüm:* iOS eCPM öncesi/sonrası.
3. **Onboarding'de değeri önce göster, hesabı sonra iste.** Şu an 3 slayt → zorunlu giriş.
   *Gerekçe:* Kayıt duvarı, değer görülmeden gelen en büyük terk noktasıdır. *Ölçüm:* onboarding tamamlama oranı.
4. **Kişiselleştirme sorusu ekle** ("neyi bırakıyorsun?", "günde ne kadar harcıyorsun?").
   *Gerekçe:* Yatırım (sunk cost) hissi ve kişiselleştirilmiş rakamlar (birikecek para)
   ikna gücünü artırır. *Ölçüm:* onboarding → paywall görüntüleme oranı.
5. **Paywall'ı doğru ana bağla.** Şu an tanıtımlar 7. günden sonra çıkıyor (iyi karar).
   Ek olarak *kilometre taşı kutlamasından hemen sonra* göstermek en yüksek dönüşümlü andır.
6. **Gerçek sosyal kanıt ekle** (yalnızca doğrulanabilirse: gerçek kullanıcı sayısı /
   mağaza puanı). Uydurma yorum **kesinlikle hayır**.
7. **İptal (churn) akışı:** iptal nedenini sor, uygunsa duraklatma teklif et.
   İptali asla zorlaştırma.

---

## 10. Retention'ı Artıracak Öneriler

1. **Bildirim izni artık doğru anda isteniyor** (uygulandı) — bir sonraki adım, izin
   reddedilirse değeri anlatan yumuşak bir ön-uyarı (pre-permission) ekranı.
2. **Risk penceresi uyarısı zaten var ama Pro'ya kilitli.** İlk uyarıyı ücretsiz vermek
   değeri yaşatır; kilit sonrakilere konabilir. *(Ürün kararı.)*
3. **Uyarlanma önerisi (`adaptiveSuggestion`) çok iyi bir fikir** — kategorinin ceza
   mekaniğine karşı doğru cevap. Daha görünür hale getirilmeli.
4. **Geri kazanım (win-back):** 7+ gün girmeyen kullanıcıya, serisini hatırlatan tek
   bir kişiselleştirilmiş bildirim.
5. **Haftalık rapor** zaten var; ilkinin ücretsiz olması doğru kurgu.

---

## 11. Eklenmesi Gereken Özellikler

| Özellik | Hedef metrik | Zorluk |
|---------|--------------|--------|
| Analytics + huni ölçümü | Dönüşüm görünürlüğü | Orta |
| ATT izin akışı (iOS) | iOS reklam geliri | Düşük |
| Abonelik yönetimi kısayolu | Destek yükü ↓ | Düşük |
| Erişilebilirlik geçişi (Semantics, kontrast) | Mağaza kalitesi | Orta |
| CI (lint + test + build) | Regresyon önleme | Düşük |

---

## 12. Teknik Borçlar

1. `store.dart` God class → modüllere ayrılmalı.
2. 48 sessiz `catch (_)` → en azından Sentry'ye breadcrumb düşmeli.
3. Silinmiş dosyalar commit edilmemiş; çalışma ağacı kirli (**58 dosya değişik**).
4. 42 paket güncel değil; `supabase_flutter` `anonKey` eskitilmiş (`publishableKey`).
5. Test kapsamı ekranları ve satın alma akışını kapsamıyor.
6. CI yok.

---

## 13. Önceliklendirilmiş Yol Haritası

### Hemen (bu oturumda yapıldı)
| Madde | Etki | Zorluk | Öncelik |
|-------|------|--------|---------|
| F-001 · Bulut veri ezilmesi | 10 | 4 | Yüksek ✅ |
| F-002 · Çevrimdışı veri kaybı | 10 | 4 | Yüksek ✅ |
| F-003 · Ömür boyu doğrulama | 9 | 3 | Yüksek ✅ |
| F-004 · Yasal bağlantılar | 9 | 2 | Yüksek ✅ |
| F-005 · Hesap silme geri bildirimi | 7 | 2 | Yüksek ✅ |
| F-006 · Bildirim izni zamanlaması | 8 | 2 | Yüksek ✅ |
| F-007 · UMP rıza | 8 | 3 | Yüksek ✅ |
| F-008 · Ayrıştırma dayanıklılığı | 8 | 3 | Yüksek ✅ |

### Kısa vade (1–2 hafta)
| Madde | Etki | Zorluk | Öncelik |
|-------|------|--------|---------|
| Edge Function'ı deploy et + ömür boyu satın almayı sandbox'ta test et | 10 | 2 | Yüksek |
| Yasal sayfaların yayında olduğunu doğrula | 9 | 1 | Yüksek |
| Analytics + huni | 9 | 5 | Yüksek |
| ATT izin akışı | 7 | 3 | Yüksek |
| Makbuzu kullanıcıya bağla (S-01) | 6 | 5 | Orta |
| CI kur | 5 | 2 | Orta |

### Orta vade (1–3 ay)
| Madde | Etki | Zorluk | Öncelik |
|-------|------|--------|---------|
| Onboarding'i değer-önce kurgusuna çevir | 8 | 6 | Orta |
| `store.dart` modülerleştirme | 5 | 7 | Orta |
| Erişilebilirlik geçişi | 6 | 5 | Orta |
| Ekran/satın alma testleri | 6 | 6 | Orta |

---

## 14. Ölçüm Planı

| Değişiklik | Metrik | Araç | Süre |
|-----------|--------|------|------|
| F-001/F-002 | "verim kayboldu" destek talebi ve 1-yıldız yorum sayısı | Mağaza konsolu | 4 hafta |
| F-003 | `rutin_pro_lifetime` başarılı satın alma sayısı (şu an **0 olmalı**) | Play/ASC | 2 hafta |
| F-006 | Bildirim izni kabul oranı | Platform raporu | 4 hafta |
| F-007 | EEA'da reklam gösterim/eCPM | AdMob | 4 hafta |
| ATT (yapılacak) | iOS eCPM | AdMob | 4 hafta |
| Paywall beyanı | İade oranı | ASC / Play | 8 hafta |

---

## 15. Varsayımlar ve Açık Sorular

1. **`kprens.github.io/rutin-legal` yayında mı?** Bağlantılar bu adrese işaret ediyor.
   `/kullanim-kosullari` sayfası yoksa Apple'ın standart EULA adresi `legal.dart` içinde hazır.
2. **App Store Connect / Play Console'da `rutin_pro_lifetime` gerçekten tanımlı mı?**
   Tanımlı değilse paywall'da zaten gizleniyor ve F-003 bugüne kadar gelir kaybettirmemiştir.
   Tanımlıysa **bugüne kadar yapılan tüm ömür boyu satın almalar açılmamıştır** — bu
   kullanıcılara Pro'nun elle verilmesi ve iade değerlendirilmesi gerekir.
3. **"7 Gün Ücretsiz Dene" için mağazada gerçekten introductory offer tanımlı mı?**
   Değilse buton yanıltıcı beyan olur (kullanıcı anında ücretlendirilir). **Doğrulanmalı.**
4. **App Privacy / Data Safety formlarında izleme (tracking) beyan edildi mi?**
   Edildiyse ATT akışı zorunlu.
5. **Çalışma ağacında 58 değişik dosya var** (silinmiş ekranlar, ikonlar, `main.dart.bak`).
   Bu devam eden bir refactor mu? Commit stratejisi netleşmeli — bu denetimdeki
   değişiklikler o kirliliğin üstüne bindi.
6. Gerçek kullanıcı/dönüşüm verisi **yok**; bu rapordaki tüm etki tahminleri kod
   okumasına dayanır.

---

## 16. Analytics — Dönüşüm Hunisi Ölçümü (eklendi)

Denetimin en öncelikli eksiği ("ürün ölçülemiyor") kapatıldı.

### Sağlayıcı kararı: kendi Supabase tablomuz

Firebase/Amplitude yerine Supabase seçildi çünkü:
- Supabase **zaten kurulu** — yeni bağımlılık, SDK veya native yapılandırma dosyası yok.
- Rutin bir **bağımlılık bırakma** uygulaması. Kullanıcının nüks ettiği anı üçüncü taraf
  bir reklam/analitik şirketine göndermek hem etik olarak savunulamaz hem de App Privacy /
  Data Safety beyanlarını ("üçüncü taraflarla paylaşılan veri") ciddi şekilde ağırlaştırır.
- Huni analizi SQL'in en iyi olduğu iştir.

**Geri dönüşü kolay:** `AnalyticsSink` arayüzü sayesinde Firebase/PostHog'a geçmek tek bir
sınıf yazmak demek; 30+ çağrı yerinin hiçbiri değişmez.

### Gizlilik güvencesi (kod düzeyinde zorlanıyor)

`Analytics._sanitize()` yalnızca sayı, bool ve **boşluksuz, ≤40 karakter** metinleri geçirir.
Alışkanlık adı, kullanıcı adı, mektup metni, hata mesajı gibi serbest girdiler **filtreden
geçemez** — bu, tek tek çağrı yerlerine güvenmek yerine merkezî bir garanti. 5 test bunu kilitler.
Ayarlar'a opt-out toggle'ı eklendi.

### Ölçülen huni

`app_open → onboarding_start → onboarding_step → onboarding_complete → auth_start →
auth_success → paywall_view → plan_select → purchase_start → purchase_success / purchase_fail`

Ek olarak: `paywall_dismiss` (vazgeçme — en büyük kayıp noktası), `purchase_cancel`,
`purchase_restore`, `rewarded_*`, ve retention için `habit_check`, `streak_relapse`.

**En değerli tek parametre `source`:** paywall'ın 7 giriş noktasının (profil, temalar,
içgörüler, haftalık rapor, arkadaşlar, iyileşme zaman çizelgesi) hangisinin gerçekten
sattığı artık ölçülebiliyor.

**Doğrudan denetim bulgularına bağlı:** `purchase_fail` olayı `reason: verification_failed`
ile F-003'ün tekrarını anında görünür kılar — kullanıcı ödeyip Pro alamazsa artık sessiz kalmaz.

### Dayanıklılık
- Olaylar kuyruğa alınır, 20'lik gruplar hâlinde ve 30 sn'de bir gönderilir.
- Çevrimdışıysa diske yazılır, uygulama kapansa bile kaybolmaz.
- Kuyruk 500 olayla sınırlı; hiçbir hata kullanıcı akışına sızmaz.
- Açılışta 3 sn timeout ile sınırlı — ölçüm katmanı açılışı geciktiremez.

### Kullanıma alma
```bash
# 1) Tabloyu ve RLS politikalarını kur
#    Supabase Dashboard → SQL Editor → supabase_analytics.sql içeriğini çalıştır
# 2) Hazır huni sorguları aynı dosyanın altında yorum olarak duruyor
```

---

## Not: Dağıtım gerektiren değişiklikler

1. **Edge Function** — yayına alınmadan ömür boyu düzeltmesi (F-003) etkin olmaz:
```bash
supabase functions deploy verify-receipt --no-verify-jwt
```

2. **Analytics tablosu** — `supabase_analytics.sql` Supabase SQL Editor'de bir kez
   çalıştırılmalı. Çalıştırılmazsa uygulama normal çalışır, olaylar sessizce
   gönderilemez (kuyrukta birikir ve zamanla düşer).
