# Faz 3 — Triyaj ve Uygulama Planı

## 1. Özet tablo

| Kategori | P0 | P1 | P2 | P3 | Toplam |
|---|---|---|---|---|---|
| bugs | 0 | 1 | 0 | 0 | 1 |
| tests | 0 | 1 | 0 | 0 | 1 |
| security | 0 | 0 | 1 | 0 | 1 |
| devops | 0 | 0 | 2 | 1 | 3 |
| quality (arch dâhil) | 0 | 0 | 3 | 4 | 7 |
| **Toplam** | **0** | **2** | **6** | **5** | **13** |

## 2. Uygulama sırası

Kullanıcı "hepsini uygula" dedi. Ancak protokolün kendi 4. maddesi riskli düzeltmeler için ayrı
onay şart koşuyor. Bu yüzden iş **iki gruba** ayrıldı.

### GRUP A — düşük riskli, hemen uygulanabilir (7 bulgu)

Sıra bağımlılığa göre; her biri ayrı commit, her commit sonrası analiz+test.

| # | ID | İş | Risk | Efor |
|---|---|---|---|---|
| 1 | **BUG-001** | Arka plan izolatındaki cast'ı tip kontrolüne çevir + regresyon testi | low | S |
| 2 | **ARCH-001** | `rutinAppBar`'ı `rutin_ui.dart`'a taşı, 8 import güncelle | low | S |
| 3 | **QUAL-004** | `themes_screen.dart`'ı `lib/ui/` altına taşı | low | S |
| 4 | **ARCH-003** | `main_ui.dart` mükerrer entrypoint'i kaldır | low | S |
| 5 | **QUAL-003** | `RError`'ı ya kullan ya kaldır | low | S |
| 6 | **DEVOPS-003** | CI push tetikleyicisini genişlet | low | S |
| 7 | **DEVOPS-002** | CI'ya iOS derleme işi + bağımlılık raporu adımı ekle | low | M |

**Bağımlılık:** #2 ve #3 aynı dosyalara (`settings_screen`, ekran importları) dokunuyor — sırayla
yapılmalı, paralel değil.

### GRUP B — YÜKSEK RİSKLİ, ayrı onay gerekiyor (3 bulgu)

`risk_of_fix: high`. Bunlar davranış/derleme zincirini geniş yüzeyde değiştiriyor ve
**uygulama şu anda App Store incelemesinde** (Waiting for Review, build 14).

| ID | İş | Neden riskli |
|---|---|---|
| **QUAL-001** | `store.dart` (1489 satır) modüllere ayırma | Fan-in 23 — 23 dosyayı etkiler; regresyon yüzeyi projedeki en geniş alan |
| **DEVOPS-001** | 21 bağımlılığı yükseltme (KGP borcu) | Derleme zincirini değiştirir; Android/iOS derlemesini kırma ihtimali gerçek |
| **SEC-001** | Makbuz doğrulamayı kullanıcıya bağlama | **Gelir akışına dokunuyor.** Hatalı bir adım = ödeme alınıp Pro açılmaması |

### TEST-001 — ayrı ele alınacak (P1 ama efor L)

Kapsam artırma tek bir "düzeltme" değil, süregiden bir iş. Grup A tamamlandıktan sonra
**hedefli** olarak en değerli üç alana test yazılması önerilir: `Iap` ürün çözümleme, paywall
durum makinesi, `store.dart` gün dönümü/budama mantığı. Bu, QUAL-001 refactor'ünün de ön koşulu —
testsiz bir God class'ı bölmek riski katlar.

## 3. Uygulanmayacaklar (öneri olarak kalır)

- **ARCH-002** (dairesel bağımlılıklar): düzeltmesi navigasyonu merkezî bir yönlendiriciye taşımayı
  gerektirir — bu, istenmeyen bir mimari yeniden yazım. Kapsam sızması olur. Öneri olarak kalıyor.
- **QUAL-002** (200+ satırlık `build()` metodları): 6 ekranın yeniden yapılandırılması. Davranış
  değiştirmeden yapılabilir ama diff'i devasa olur ve inceleme sürerken görsel regresyon riski taşır.

## 4. Açık sorular

`audit/questions.md` dosyasına yazıldı.

## 5. Doğrulama protokolü (her commit sonrası)

```bash
flutter analyze --no-pub --fatal-warnings   # 0 hata / 0 uyarı olmalı
flutter test --no-pub                        # 60/60 (yeni testlerle artacak)
```

Android/iOS derlemesi yalnızca native dosyalara dokunan değişikliklerden sonra çalıştırılır.
