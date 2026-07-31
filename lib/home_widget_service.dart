/// Ana ekran widget'ı (Android App Widget + iOS WidgetKit) köprüsü.
///
/// Widget, o günün alışkanlıklarını (en fazla [_maxWidgetTasks] tanesini) ve
/// tamamlanma durumlarını gösterir; bir satıra dokunmak checkbox'ı ANINDA
/// widget üzerinde çevirir (uygulamayı açmadan). Gerçek kayıt şu akışla olur:
///
///  1. [syncHomeWidget] — AppState her değiştiğinde (bkz. store.dart) o günün
///     görev listesini + tamamlanma durumunu widget'ın kendi depolamasına
///     (SharedPreferences/UserDefaults, `home_widget` paketi üzerinden) yazar.
///  2. Kullanıcı widget'ta bir satıra dokunur → Android/iOS bunu arka planda,
///     UYGULAMA AÇIK OLMASA BİLE, [backgroundCallback]'i tetikleyerek bildirir
///     (ayrı/minimal bir Flutter motoru ile — tam UI yok). Bu callback widget
///     verisindeki "done" bayrağını çevirip widget'ı hemen günceller (anında
///     görsel geri bildirim) VE dokunulan görev id'sini "bekleyen değişiklik"
///     kuyruğuna ekler.
///  3. Uygulama bir sonraki açılışında/öne gelişinde
///     [applyPendingWidgetToggles] bu kuyruğu okur, her id için GERÇEK
///     [AppState.toggleTask]'ı çağırır (yerel/bulut hangi repository
///     kullanılıyorsa ondan geçer) ve kuyruğu temizler.
///
/// Bu iki aşamalı tasarım sayesinde arka plan callback'inin Supabase/bulut
/// senkronizasyonu hakkında hiçbir şey bilmesine gerek kalmıyor — sadece bir
/// not bırakıyor, asıl kayıt uygulama açıldığında normal yoldan işleniyor.
library;

import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// DİKKAT — bu dosya `store.dart`'ı BİLEREK import etmez.
///
/// Eskiden ediyordu ve iki dosya birbirini import ediyordu (döngüsel
/// bağımlılık): servis `AppState` alıyordu, `AppState` de servisi 7 yerden
/// çağırıyordu. Döngü iki somut soruna yol açıyordu:
///
///   • Servis, uygulamanın TÜM durum sınıfına bağlıydı; oysa ihtiyacı olan
///     yalnızca bir görev listesi. Bu yüzden `AppState` kurmadan test
///     edilemiyordu — üstelik bu dosya arka plan izolatından da çalışıyor,
///     yani orada tam bir AppState hiç yok.
///   • Değişikliklerin etkisi izlenemiyordu: widget'a dokunan bir düzenleme
///     store'u, store'a dokunan bir düzenleme widget'ı etkileyebiliyordu.
///
/// Bağımlılık ters çevrildi: burası düz veri ([WidgetTask]) ve geri çağrım
/// alır, `AppState`'i hiç tanımaz. Yön artık tek: store → servis.
const _kTasksKey = 'rutin_widget_tasks';
const _kPendingKey = 'rutin_widget_pending_toggles';
const _kAndroidWidgetName = 'HabitWidgetProvider';
const _kIosWidgetName = 'RutinWidget';
const maxWidgetTasks = 5;

/// iOS'ta widget ile ana uygulamanın aynı depoyu (UserDefaults) paylaşması
/// için App Group kimliği. Xcode'da hem Runner hem widget extension
/// hedefinde "App Groups" capability'sine AYNI bu kimlik eklenmelidir.
const iosAppGroupId = 'group.com.alper.rutin';

/// main.dart → runApp() öncesinde bir kez çağrılır.
///
/// ÖNEMLİ: Tüm gövde try/catch içindedir. Bu çağrı `main()` içinde AWAIT
/// ediliyor; burada fırlatılan bir hata UYGULAMANIN HİÇ AÇILMAMASINA yol
/// açar (aynı sınıftan bir hata Sentry'nin geçersiz DSN'i yüzünden zaten
/// yaşandı — açılışta sonsuz donma). Somut riskler: iOS'ta App Group
/// capability'si henüz Xcode'da tanımlanmadığı için `setAppGroupId`
/// başarısız olabilir; `flutter test` ortamında platform kanalları hiç
/// bulunmadığı için MissingPluginException fırlar. Widget çalışmazsa
/// uygulama sadece widget'sız çalışmaya devam etmeli — asla açılmamazlık
/// etmemeli.
Future<void> initHomeWidget() async {
  try {
    await HomeWidget.setAppGroupId(iosAppGroupId);
    HomeWidget.registerInteractivityCallback(backgroundCallback);
  } catch (_) {
    // Widget desteği yok/kurulamadı — uygulama normal çalışmaya devam eder.
  }
}

/// Widget'ta gösterilecek tek bir görev — servisin uygulama durumundan
/// ihtiyaç duyduğu ALANLARIN TAMAMI.
///
/// `TaskItem` yerine ayrı bir tip olması bilinçli: servis o zaman
/// `store.dart`'a bağlanır ve döngü geri gelir. Buradaki dar yüzey aynı
/// zamanda sözleşmeyi görünür kılıyor — widget'ın kullanıcı verisinden
/// yalnızca bu dört alanı gördüğü tek bakışta okunuyor.
class WidgetTask {
  const WidgetTask({
    required this.id,
    required this.name,
    required this.emoji,
    required this.done,
  });

  final int id;
  final String name;
  final String emoji;
  final bool done;
}

/// Widget'ı çizmek için gereken her şey: gösterilecek satırlar ve GÜNÜN
/// gerçek ilerlemesi. İkisi ayrı çünkü satırlar kırpılmış, sayaç değil.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.tasks,
    required this.doneToday,
    required this.totalToday,
  });

  final List<WidgetTask> tasks;
  final int doneToday;
  final int totalToday;
}

/// Güncel görev listesini widget'ın kendi deposuna yazar ve native tarafın
/// yeniden çizmesini ister. store.dart; toggleTask(), load() ve
/// dailyRollover() sonunda bunu çağırır.
///
/// [tasks] ÇAĞIRAN tarafından kırpılmış gelmeli (bkz. [maxWidgetTasks]).
///
/// [doneToday] / [totalToday] ise GÜNÜN TAMAMINI anlatır, gösterilen
/// satırları değil — ayrı parametre olmalarının sebebi bu.
///
/// Eski kod payı günün TÜM tamamlananlarından, paydayı ise widget'ta
/// görünen en fazla 5 satırdan alıyordu. 8 görevden 6'sı bitmişse widget
/// "6/5" gösteriyordu. Sayaç artık iki ucunu da aynı kümeden alıyor.
///
/// (Widget platformu yoksa/başarısızsa sessizce yok sayılır — bkz.
/// [initHomeWidget]'teki açıklama; bu fonksiyon store.dart'ta her veri
/// değişiminde çağrıldığı için burada fırlayan bir hata uygulamanın normal
/// akışını bozmamalı.)
Future<void> syncHomeWidget(
  List<WidgetTask> tasks, {
  required int doneToday,
  required int totalToday,
}) async {
  try {
    final list = tasks
        .map((t) => {
              'id': t.id,
              'name': t.name,
              'emoji': t.emoji.isNotEmpty ? t.emoji : '✅',
              'done': t.done,
            })
        .toList();
    await HomeWidget.saveWidgetData(_kTasksKey, jsonEncode(list));
    await HomeWidget.saveWidgetData(
        'rutin_widget_summary', '$doneToday/$totalToday');
    await HomeWidget.updateWidget(
        androidName: _kAndroidWidgetName, iOSName: _kIosWidgetName);
  } catch (_) {
    // Widget güncellenemedi — uygulama akışı etkilenmez.
  }
}

/// Uygulama açıldığında/öne geldiğinde (bkz. AppState.boot(),
/// root_shell.dart didChangeAppLifecycleState) widget'ta biriken "bekleyen"
/// dokunmaları gerçek [AppState.toggleTask] ile işler.
/// (Widget platformu yoksa/başarısızsa sessizce yok sayılır — bu fonksiyon
/// AppState.load() içinde AWAIT ediliyor, dolayısıyla buradan fırlayan bir
/// hata tüm veri yüklemesini ve uygulama açılışını bozardı.)
/// [onToggle] her bekleyen görev kimliği için çağrılır; o kimliği gerçekten
/// işaretlemek çağıranın (store) işi. Servis görev listesini tanımadığı için
/// eşleştirmeyi de yapamaz — döngüyü kıran nokta tam olarak burası.
///
/// [snapshot] işlem bittikten sonraki güncel durumu döndürmeli; widget
/// onunla yeniden çizilir.
Future<void> applyPendingWidgetToggles({
  required void Function(int taskId) onToggle,
  required WidgetSnapshot Function() snapshot,
}) async {
  String? raw;
  try {
    raw = await HomeWidget.getWidgetData<String>(_kPendingKey);
  } catch (_) {
    return;
  }
  if (raw == null || raw.isEmpty) return;
  List<dynamic> ids;
  try {
    ids = jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return;
  }
  for (final idRaw in ids) {
    final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
    if (id == null) continue;
    onToggle(id);
  }
  try {
    await HomeWidget.saveWidgetData(_kPendingKey, '[]');
  } catch (_) {
    // yok sayılır
  }
  final snap = snapshot();
  await syncHomeWidget(snap.tasks,
      doneToday: snap.doneToday, totalToday: snap.totalToday);
}

/// Widget'a dokunulduğunda tetiklenir — AYRI/minimal bir Flutter motorunda
/// çalışır, tam uygulama state'ine erişemez. Bu yüzden sadece widget'ın
/// KENDİ deposundaki "done" bayrağını çevirip anında görsel geri bildirim
/// verir ve gerçek işlemi ana uygulamaya bırakan bir not (bekleyen kuyruk)
/// bırakır (bkz. dosya başı açıklaması).
/// Widget görev listesinde [id]'li kaydın `done` bayrağını çevirir ve
/// tamamlanan sayısını döndürür. Saf fonksiyon — platform kanalına
/// dokunmaz, bu yüzden doğrudan test edilebilir.
///
/// BOZUK VERİYE KARŞI ASLA FIRLATMAZ. Bu bir tercih değil zorunluluk:
/// çağıran [backgroundCallback] ayrı bir Flutter izolatında çalışır ve
/// üstünde hiçbir yakalayıcı yoktur. Eskiden burada `item as
/// Map<String, dynamic>` çıplak cast'ı vardı; dizideki tek bir sayı ya da
/// null TypeError fırlatıyor, widget dokunuşu sessizce kayboluyordu.
/// (Aynı dosyadaki [_flushPending] bu deseni zaten tip kontrollü yazmıştı —
/// tutarsızlık buradaydı.)
///
/// Bozuk elemanlar SİLİNMEZ, yalnızca atlanır: veri kaybı yaratmadan
/// devam etmek, sessizce kaybolmaktan da veriyi budamaktan da iyidir.
({List<dynamic> list, int doneCount}) toggleWidgetTasks(
    List<dynamic> list, int id) {
  // Girdi haritaları YERİNDE DEĞİŞTİRİLMEZ; her biri gevşek tipli bir
  // kopyaya alınır.
  //
  // Sebebi Dart'ın kovaryansı: `Map<String, int>` de `is Map<String, dynamic>`
  // kontrolünden GEÇER, dolayısıyla tip kontrolü `item['done'] = true`
  // yazarken oluşacak TypeError'ı engellemez. Kopya üzerinde çalışmak bu
  // tuzağı tamamen ortadan kaldırır ve fonksiyonun "asla fırlatmaz"
  // sözleşmesini tipten bağımsız hale getirir — çağıran, yakalayıcısı
  // olmayan bir izolat.
  final out = <dynamic>[];
  var doneCount = 0;
  for (final item in list) {
    if (item is! Map) {
      out.add(item); // bozuk eleman korunur, veri kaybı olmaz
      continue;
    }
    final m = <String, dynamic>{};
    item.forEach((k, v) => m['$k'] = v);
    if (m['id'] == id) {
      m['done'] = !(m['done'] == true);
    }
    if (m['done'] == true) doneCount++;
    out.add(m);
  }
  return (list: out, doneCount: doneCount);
}

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'toggle') return;
  final idStr = uri.queryParameters['id'];
  final id = int.tryParse(idStr ?? '');
  if (id == null) return;

  final raw = await HomeWidget.getWidgetData<String>(_kTasksKey);
  if (raw == null) return;
  List<dynamic> list;
  try {
    list = jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return;
  }
  final toggled = toggleWidgetTasks(list, id);
  await HomeWidget.saveWidgetData(_kTasksKey, jsonEncode(toggled.list));
  await HomeWidget.saveWidgetData(
      'rutin_widget_summary', '${toggled.doneCount}/${toggled.list.length}');

  final pendingRaw = await HomeWidget.getWidgetData<String>(_kPendingKey);
  List<dynamic> pending = [];
  if (pendingRaw != null && pendingRaw.isNotEmpty) {
    try {
      pending = jsonDecode(pendingRaw) as List<dynamic>;
    } catch (_) {
      pending = [];
    }
  }
  if (!pending.contains(id)) pending.add(id);
  await HomeWidget.saveWidgetData(_kPendingKey, jsonEncode(pending));

  await HomeWidget.updateWidget(
      androidName: _kAndroidWidgetName, iOSName: _kIosWidgetName);
}
