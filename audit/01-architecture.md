# Faz 1 — Mimari Haritalama

Dal: `chore/audit-2026-07-29` · Yöntem: hedefli `grep`/AST-benzeri tarama (subagent değil — 1 numaralı
kural her bulgu için `dosya:satır` kanıtı şart koşuyor, özet döndüren subagent bu kesinliği kaybettirir).

## 1. Katmanlar

```
                    ┌──────────────────────────────┐
   Giriş noktaları  │ main.dart:47   (üretim)      │
                    │ main_ui.dart:11 (aynı şeyi   │
                    │   çağıran ikinci entrypoint) │
                    │ home_widget_service.dart:132 │
                    │   backgroundCallback         │
                    │   (@pragma vm:entry-point,   │
                    │    AYRI izolat)              │
                    └──────────────┬───────────────┘
                                   │
   Sunum (lib/ui/*)   20 ekran + rutin_ui.dart (UI kit) + ui_logic.dart
                                   │
   Durum              store.dart (AppState · ChangeNotifier · 1489 satır)
                                   │
   Servis             iap · ads · analytics · notifications · friends ·
                      auth · home_widget_service · diagnostics · legal
                                   │
   Veri               repository.dart (LocalRepository / SupabaseRepository)
                                   │
   Dış dünya          Supabase (Auth/Postgres/Edge Fn) · StoreKit/Play Billing
                      AdMob · Sentry · flutter_local_notifications
```

## 2. Bağımlılık grafiği — fan-in (kaç dosya import ediyor)

| Modül | Fan-in | Değerlendirme |
|---|---|---|
| `l10n.dart` | 31 | Beklenen — çeviri yaprağı, bağımlılığı yok |
| `store.dart` | 23 | **Merkezi düğüm.** Değişikliği 23 dosyayı etkiler |
| `rutin_ui.dart` | 21 | Beklenen — UI kit |
| `models.dart` | 14 | Beklenen — veri modelleri |
| `analytics.dart` | 9 | Kabul edilebilir |
| **`water_screen.dart`** | **8** | **Katman ihlali — aşağıya bak** |
| `ui_logic.dart` | 7 | Kabul edilebilir |

## 3. Tespit edilen mimari sorunlar

### ARCH-A · Paylaşılan UI bileşeni bir EKRAN dosyasında yaşıyor

`rutinAppBar` `lib/ui/water_screen.dart:329`'da tanımlı ve **8 ekran** bunu almak için su ekranını
import ediyor:

```
lib/ui/paywall_screen.dart      lib/ui/settings_screen.dart
lib/ui/insights_screen.dart     lib/ui/friends_screen.dart
lib/ui/recovery_timeline_screen.dart  lib/ui/achievements_screen.dart
lib/ui/weekly_report_screen.dart      lib/ui/letter_screen.dart
```

Paylaşılan bileşenin doğru yeri `rutin_ui.dart` (UI kit). Şu hâliyle bir uygulama içi satın alma
ekranı, su takip ekranının tüm bağımlılıklarını sürüklüyor.

### ARCH-B · Dairesel bağımlılıklar (3 döngü)

**Döngü 1 — servis ↔ durum:**
- `lib/store.dart:14` → `home_widget_service.dart`
- `lib/home_widget_service.dart:30` → `store.dart`

Katman ihlali: veri/servis katmanı, kendisini kullanan durum katmanına geri bağımlı.

**Döngü 2 — navigasyon grafiği tamamen çevrimsel:**
- `lib/ui/onboarding_screen.dart:6` → `auth_screen`
- `lib/ui/auth_screen.dart:9` → `root_shell`
- `lib/ui/root_shell.dart:18` → `profile_screen`
- `lib/ui/profile_screen.dart:17` → `onboarding_screen` ← **döngüyü kapatıyor**

**Döngü 3 —** aynı zincir `profile_screen.dart:14` → `settings_screen` → `settings_screen.dart:14`
→ `onboarding_screen` üzerinden de kapanıyor.

Dart bunu derler, çalışma zamanı hatası değil. Ama her ekranın her ekranı doğrudan `push` edebilmesi
demek: navigasyon sorumluluğu hiçbir yerde merkezî değil, akış değişikliği n dosyaya yayılıyor.

### ARCH-C · Mükerrer giriş noktası

`lib/main_ui.dart:11` yalnızca `main.dart`'ın `main()`'ini çağırıyor. Tarihsel bir kalıntı;
kendi dokümantasyonu bile "artık birebir aynı üretim uygulamasını başlatır" diyor.

## 4. Güven sınırları (trust boundaries) — Faz 2 güvenlik taramasının girdisi

| # | Sınır | Konum | Not |
|---|---|---|---|
| TB-1 | E-posta / parola / ad girdisi | `lib/ui/auth_screen.dart:44-56` | İstemci doğrulaması var (regex + 6 karakter) |
| TB-2 | Kullanıcı metni (alışkanlık/bırakma adları) | `store.dart` → bildirim + widget + dışa aktarma | Bildirim metnine ve widget'a giriyor |
| TB-3 | **Widget URI** | `lib/home_widget_service.dart:132-136` | Ayrı izolat; `host != 'toggle'` filtreli, `int.tryParse` ile korumalı |
| TB-4 | **Widget deposundaki JSON** | `lib/home_widget_service.dart:138-151` | ⚠️ satır 148 korumasız cast — Faz 2'ye taşındı |
| TB-5 | Supabase yanıtları | `lib/repository.dart`, `lib/friends.dart` | `app_data`, `profiles`, `friendships` tabloları |
| TB-6 | Mağaza makbuzu / ürün verisi | `lib/iap.dart` | Doğrulama Edge Function'a gidiyor |
| TB-7 | **Kimlik doğrulamasız Edge Function** | `supabase/functions/verify-receipt` | `--no-verify-jwt` ile deploy; makbuz kullanıcıya bağlı değil |
| TB-8 | Harici URL açma | `lib/legal.dart:66-84` | Sabit sabitlerden besleniyor |

## 5. Dış bağımlılıklar

Supabase (Auth + Postgres + Edge Functions, AB/Frankfurt) · Apple StoreKit · Google Play Billing ·
Google AdMob (+ UMP rıza) · Sentry · flutter_local_notifications · home_widget · sign_in_with_apple

## 6. Ölü / şüpheli kod (Faz 2'de doğrulanacak)

- `lib/ui/rutin_ui.dart` → `RError` sınıfı: tanımlı, **hiçbir yerde kullanılmıyor**
- `lib/main_ui.dart`: yalnızca yeniden yönlendirme yapan mükerrer entrypoint
- `lib/screens/themes_screen.dart`: tek başına eski klasör düzeninde kalmış (diğer 20 ekran `lib/ui/`)

## 7. Faz 1 sonucu

Mimari **katmanlı ve okunabilir**; kritik bir yapısal bozukluk yok. Ancak üç yerde sorumluluk
sınırları bulanık: paylaşılan bileşenin ekran dosyasında olması, servis↔durum döngüsü ve merkezî
olmayan navigasyon. Hiçbiri acil değil; hepsi bakım maliyetini artırıyor.
