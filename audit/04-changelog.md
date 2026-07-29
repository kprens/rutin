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
