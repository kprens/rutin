# Faz 2 — Bulgular

13 bulgu · **P0: 0** · P1: 2 · P2: 6 · P3: 5
Tek doğruluk kaynağı: `audit/02-findings.json`

> **Kalibrasyon notu:** Hiç P0 yok ve bu doğru. Baseline yeşil (analiz 0 hata, 60/60 test),
> sömürülebilir güvenlik açığı, veri kaybı veya açılışta çöküş bulunamadı. Her şeyi P0
> yapmak, gerçek P0 çıktığında sinyali yok eder.

---

## P1 — Yanlış davranış / kritik yol testsiz

### BUG-001 · Arka plan izolatında korumasız cast
`lib/home_widget_service.dart:148`

```dart
final m = item as Map<String, dynamic>;   // ← çıplak cast
```

`jsonDecode` satır 141-145'te try ile korunuyor, ama dizinin **elemanları** üzerindeki cast
korumasız. Kanıtın gücü şurada: **aynı dosyanın 112. satırında** aynı desen doğru yazılmış —

```dart
final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
if (id == null) continue;
```

Yani bu bilinçli bir tercih değil, gözden kaçma.

`backgroundCallback` **ayrı bir Flutter izolatında** çalışır ve üstünde yakalayıcı yoktur.
(Karşılaştırma: `friends.dart`'taki benzer cast'lar `store.dart:151-172` tarafından yakalanıp
kullanıcıya hata mesajına dönüşüyor — orada sorun yok.) Burada hata yutulmaz: widget dokunuşu
işlenmez, kullanıcı sebebini anlamaz.

**Etki:** Ana ekran widget'ından görev işaretleme sessizce çalışmaz.

---

### TEST-001 · Kapsam düşük, gelir ve navigasyon yolları testsiz
`coverage/lcov.info` → **375/1845 = %20,3**

lcov yalnızca testlerin yüklediği dosyaları sayar. Proje 16.087 satır; **gerçek kapsam bunun
belirgin altında.**

Bunun soyut bir metrik olmadığının kanıtı: bu oturumda tam bu boşluktan doğan iki hata bulundu —
paywall'ın sonsuz yükleme çıkmazı ve `home_logic` modülünün üretimde hiç çağrılmıyor olması
(testler yeşil olmasına rağmen). **Testler yanlış güven veriyordu.**

---

## P2 — Bakım / kalite borcu

| ID | Bulgu | Kanıt |
|---|---|---|
| **SEC-001** | verify-receipt kimlik doğrulamasız, makbuz kullanıcıya bağlı değil | `supabase/functions/verify-receipt/index.ts:8,54` |
| **DEVOPS-001** | 21 eski bağımlılık + 7 eklenti KGP kullanıyor → gelecek Flutter'da Android derlemesi kırılır | `pubspec.lock`, derleme uyarısı |
| **DEVOPS-002** | CI'da iOS derlemesi ve bağımlılık denetimi yok | `.github/workflows/ci.yml:34,64` |
| **QUAL-001** | `store.dart` 1489 satır, fan-in 23 (God class) | `lib/store.dart` |
| **QUAL-002** | 6 `build()` metodu 200+ satır (49 fonksiyon 50+ satır) | `friends_screen.dart:114` (323), `paywall_screen.dart:112` (264) |
| **ARCH-001** | `rutinAppBar` ekran dosyasında; 8 ekran su ekranını import ediyor | `lib/ui/water_screen.dart:329` |

**SEC-001 hakkında şiddet düzeltmesi:** Önceki denetim (`AUDIT.md` S-01) bunu *"replay ile Pro
açılabilir"* diye tanımlamış. Kodu okuyunca şiddet **daha düşük** çıkıyor: uç nokta yalnızca
`{valid}` döndürüyor, Pro'yu **istemci** açıyor — sunucuda çalınacak bir hak yok. Gerçek risk,
uç noktanın Apple/Google API'lerine ücretsiz vekil olarak kötüye kullanılması. P2.

---

## P3 — Kozmetik / tutarlılık

| ID | Bulgu | Kanıt |
|---|---|---|
| **ARCH-002** | 3 dairesel bağımlılık döngüsü | `store.dart:14` ↔ `home_widget_service.dart:30`; `profile_screen.dart:17` |
| **DEVOPS-003** | CI push tetikleyicisi yalnızca `main`, `theme-update` | `.github/workflows/ci.yml:15` |
| **QUAL-003** | `RError` tanımlı ama kullanılmıyor | `lib/ui/rutin_ui.dart:565` |
| **QUAL-004** | `themes_screen.dart` eski klasörde | `lib/screens/themes_screen.dart` |
| **ARCH-003** | Mükerrer giriş noktası | `lib/main_ui.dart:11` |

---

## Tarandı ve TEMİZ çıktı (bulgu üretilmedi)

- `eval` / `Process.run` / `dart:mirrors` — yok
- **Kodda gömülü sır — yok.** `build_release.sh` gerçek anahtarlar içeriyor ama git'te
  **izlenmiyor**, `.gitignore:52`'de ve **geçmişte de hiç bulunmamış** (doğrulandı)
- Şifresiz `http://` çağrısı — yok
- Zayıf hash (md5/sha1) — yok
- SQL enjeksiyonu — ham SQL yok; tüm erişim Supabase istemcisi üzerinden parametreli
- TODO/FIXME/HACK — yok

### Bulgu sayılmayan iki gözlem (dürüstlük için kaydedildi)

- `friends.dart:252-258` korumasız cast'lar → **çağıran yakalıyor** (`store.dart:151-172`),
  kullanıcıya düzgün hata gösteriliyor. Bulgu değil.
- `notifications.dart:111-192` döngü içi `await` → yerel eklenti çağrısı, ağ değil. Sıralı
  olması doğru. Bulgu değil.

---

## Ölçülmedi / doğrulanamadı (dürüst beyan)

- **Proje geneli gerçek test kapsamı** — lcov yalnızca yüklenen dosyaları ölçüyor
- **Performans** — frame drop, jank, bellek, soğuk açılış ölçülmedi (gerçek cihaz gerekir)
- **Erişilebilirlik** — kontrast oranları ölçülmedi; `accessibility_test.dart` var ama kapsamı dar
- **iPad / landscape düzeni** — bu denetimde test edilmedi
- **Bağımlılık zafiyetleri** — Dart ekosisteminde `npm audit` karşılığı bir tarama çalıştırılmadı
