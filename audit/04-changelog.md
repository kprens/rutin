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
