/// Veri deposu soyutlaması.
///
/// Uygulama veriyi bu arayüz üzerinden okur/yazar. Oturum yokken
/// [LocalRepository] (cihazda shared_preferences), hesabıyla giriş yapılmışsa
/// [CloudRepository] (Supabase) kullanılır — bkz. store.dart → AppState.boot.
library;

import 'dart:convert';
import 'diagnostics.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bir okuma denemesinin sonucu.
///
/// "Veri YOK" (yeni/boş hesap) ile "veri OKUNAMADI" (ağ yok, sunucu hatası)
/// birbirinden AYRI tutulmak zorunda. İkisi de `null` ile temsil edildiğinde
/// [AppState.boot] geçici bir ağ hatasını "bu hesap yepyeni" sanıp cihazdaki
/// (muhtemelen boş) veriyi buluta yazıyor ve kullanıcının gerçek bulut
/// verisini KALICI OLARAK siliyordu.
class LoadResult {
  /// Okunan veri. [missing] ya da [failed] durumunda null.
  final Map<String, dynamic>? data;

  /// Okuma başarısız oldu (ağ/sunucu). Veri VAR olabilir — bilinmiyor.
  final bool failed;

  const LoadResult.found(Map<String, dynamic> this.data) : failed = false;

  /// Okuma başarılı ama bu hesaba ait kayıt yok (gerçekten yeni hesap).
  const LoadResult.missing()
      : data = null,
        failed = false;

  const LoadResult.failure()
      : data = null,
        failed = true;
}

abstract class Repository {
  Future<LoadResult> loadAll();
  Future<void> saveAll(Map<String, dynamic> data);
}

class LocalRepository implements Repository {
  /// [scope] boşsa oturumsuz (cihaz) verisi kullanılır. Bir hesap kimliği
  /// verilirse o hesaba ÖZEL bir anahtar kullanılır — bkz. [CloudRepository]
  /// çevrimdışı önbelleği. Önbellek hesap başına ayrılmazsa, A hesabından
  /// çıkıp B hesabına girildiğinde (ve bulut okunamadığında) A'nın verisi
  /// B'ye sızardı.
  const LocalRepository({this.scope = ''});

  final String scope;

  static const _baseKey = 'rutinData';

  String get _key => scope.isEmpty ? _baseKey : '${_baseKey}_$scope';

  @override
  Future<LoadResult> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const LoadResult.missing();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const LoadResult.missing();
      return LoadResult.found(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      // Cihazdaki veri okunamadi. Bu, kullanicinin TUM gecmisini
      // kaybetmesiyle sonuclanabilecek bir durum — sessiz kalmamali.
      reportError(e, st, op: 'local_load');
      // Bozuk JSON ya da okunamayan tercih deposu. Cihazdaki veri
      // kullanılamıyor; "kayıt yok" değil "okunamadı" demek doğrusu —
      // aksi halde çağıran taraf bunu boş hesap sanıp üzerine yazar.
      return const LoadResult.failure();
    }
  }

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }
}

/// Bulut deposu — hesabıyla giriş yapan kullanıcının tüm uygulama verisini
/// (streak'ler, görevler, su takibi, takvim...) `public.app_data` tablosunda
/// (bkz. `supabase_app_data.sql`) tek bir JSON satırı olarak tutar.
///
/// Her yazma AYNI ANDA cihaza da işlenir (write-through). Eskiden bulut
/// yazması başarısız olduğunda hata sessizce yutuluyordu ve veri yalnızca
/// bellekte kalıyordu: kullanıcı çevrimdışıyken girdiği her şeyi (işaretlenen
/// görevler, su kayıtları, nüks kaydı) uygulama kapandığı anda KAYBEDİYORDU.
/// Yerel kopya sayesinde bulut erişilemezken de hiçbir veri kaybolmaz;
/// bağlantı geri geldiğinde bir sonraki kayıt tüm durumu (tek JSON belgesi
/// olarak yazıldığı için) buluta olduğu gibi taşır.
class CloudRepository implements Repository {
  const CloudRepository();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Çevrimdışı önbellek — HESABA ÖZEL anahtar kullanır ki hesaplar arası
  /// veri sızıntısı olmasın.
  LocalRepository _cacheFor(String uid) => LocalRepository(scope: uid);

  @override
  Future<LoadResult> loadAll() async {
    final uid = _uid;
    if (uid == null) return const LoadResult.failure();
    final cache = _cacheFor(uid);
    try {
      final row = await _client
          .from('app_data')
          .select('data')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return const LoadResult.missing();
      final data = Map<String, dynamic>.from(row['data'] as Map);
      // Bulut kopyası cihaza da yazılır: bir sonraki açılışta ağ yoksa
      // kullanıcı en azından bu anlık görüntüyle çalışmaya devam eder.
      await cache.saveAll(data);
      return LoadResult.found(data);
    } catch (e, st) {
      reportError(e, st, op: 'cloud_load');
      // Ağ/sunucu hatası. Bu hesaba ait son kopya varsa onunla devam et —
      // "veri yok" DEME, aksi halde çağıran taraf hesabı boş sanar.
      final cached = await cache.loadAll();
      if (cached.data != null) return LoadResult.found(cached.data!);
      return const LoadResult.failure();
    }
  }

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    // Önce cihaza: bulut erişilemese bile veri kaybolmasın.
    try {
      await _cacheFor(uid).saveAll(data);
    } catch (e, st) {
      // Yerel yedek yazilamadi: bulut da erisilemezse veri gercekten kaybolur.
      reportError(e, st, op: 'local_cache_save');
      // Yerel yazma da başarısızsa (disk dolu) yapılabilecek bir şey yok.
    }
    try {
      await _client.from('app_data').upsert({
        'user_id': uid,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      reportError(e, st, op: 'cloud_save');
      // Bulut şu an yazılamadı; veri cihazda güvende. Tüm durum tek JSON
      // belgesi olarak yazıldığı için bir sonraki başarılı kayıt eksiksiz
      // senkronizasyonu kendiliğinden sağlar.
    }
  }
}
