# Faz 0 — Keşif Envanteri

Tarih: 2026-07-29 · Dal: `chore/audit-2026-07-29` · Kapsam argümanı: `all` (belirtilmedi)

## Teknoloji yığını

| | Değer | Kaynak |
|---|---|---|
| Platform | Flutter (Dart) · iOS + Android | `pubspec.yaml:1-7` |
| Dart SDK kısıtı | `>=3.2.0 <4.0.0` | `pubspec.yaml:7` |
| Yerel araç zinciri | Flutter 3.44.5 · Dart 3.12.2 | `flutter --version` |
| CI araç zinciri | Flutter 3.44.5 | `.github/workflows/ci.yml:30` |
| Paket yöneticisi | pub | `pubspec.lock` |
| Backend | Supabase (Auth + Postgres + Edge Functions) | `lib/main.dart:116-130`, `supabase/functions/verify-receipt` |
| Uygulama sürümü | `1.0.0+15` | `pubspec.yaml:4` |

Yerel ve CI Flutter sürümleri birebir aynı — sürüm kayması kaynaklı "bende çalışıyor" riski yok.

## Komutlar (dosyadan doğrulandı, varsayım değil)

| İş | Komut | Kaynak |
|---|---|---|
| Bağımlılık | `flutter pub get` | `ci.yml:46` |
| Statik analiz + tip kontrolü | `flutter analyze --no-pub --fatal-warnings` | `ci.yml:58` |
| Test | `flutter test --no-pub` | `ci.yml:61` |
| Android debug derleme | `flutter build apk --debug` | `ci.yml:93` |
| Üretim derlemesi (her iki platform) | `./build_release.sh` | kök dizin, çalıştırılabilir |

Dart statik tipli olduğu için ayrı bir typecheck adımı yok; `flutter analyze` bu görevi de üstleniyor.

`build_release.sh` gerçek Supabase/Sentry/AdMob değerlerini `--dart-define` ile enjekte eder. Düz
`flutter build appbundle` bu değerleri katmaz — üretim derlemesi **yalnızca** bu script ile alınmalı.

## Boyut

| Metrik | Değer |
|---|---|
| İzlenen dosya | 291 |
| Dart dosyası | 50 |
| Dart satırı (toplam) | 16.087 |
| SQL dosyası | 7 |
| Swift/Kotlin | 7 swift + Kotlin (Android widget) |

En büyük dosyalar (God-class adayları, Faz 2'de incelenecek):

```
1489  lib/store.dart
 743  lib/ui/ui_logic.dart
 723  lib/ui/paywall_screen.dart
 682  lib/ui/rutin_ui.dart
 619  lib/ui/home_screen.dart
 607  lib/ui/friends_screen.dart
```

## BASELINE (denetim öncesi ölçüm)

| Metrik | Değer | Komut |
|---|---|---|
| Statik analiz | ✅ **0 hata, 0 uyarı** (`--fatal-warnings` ile) | `flutter analyze` |
| Test | ✅ **60/60 geçti** | `flutter test` |
| Satır kapsamı | ⚠️ **%20,3** (375/1845) | `flutter test --coverage` |
| Güncel olmayan bağımlılık | ⚠️ **21 paket** daha yeni sürüme kısıtlanmış | `flutter pub outdated` |
| Android debug derleme | ✅ (CI'da ve yerelde doğrulandı) | `flutter build apk --debug` |
| CI | ✅ 2 iş: "Analiz + Test", "Android derleme" | `.github/workflows/ci.yml` |

**Kapsam ölçümü hakkında uyarı:** lcov yalnızca testlerin yüklediği dosyaları sayar (1845 satır).
Projenin tamamı 16.087 satır olduğuna göre proje geneli gerçek kapsam **%20,3'ten belirgin şekilde
düşüktür**. Kesin proje geneli kapsam ölçülmedi.

## Bilinen bağlam (denetimin sınırlarını belirler)

- Uygulama **şu anda App Store incelemesinde** ("Waiting for Review", build 14 bağlı).
- `main` dalında **push edilmemiş 2 commit** var: `b27adfc`, `108c4ca` (build 15'in kaynağı).
- Repoda önceki bir denetim raporu mevcut: `AUDIT.md` (F-001…F-012). Tekrar üretmemek için Faz 2'de
  bu raporun **açık bıraktığı** kalemler ayrıca işaretlenecek.

## Faz 0 sonucu

Baseline **yeşil**. Denetim, kırık bir tabandan değil çalışan bir tabandan başlıyor; bu, ileride
oluşacak her kırmızının denetimin kendisinden kaynaklandığını kesinleştirir.
