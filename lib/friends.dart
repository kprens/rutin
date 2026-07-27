/// Arkadaş / Sorumluluk Ortağı katmanı.
///
/// Veritabanı şeması `supabase_schema.sql`'de zaten tanımlıydı (profiles,
/// friendships, shared_streaks tabloları + RLS politikaları) ama hiçbir
/// Dart kodu bu tabloları kullanmıyordu — paywall'da vaat edilen
/// "Sorumluluk Ortağı" özelliği gerçekte hiç bağlı değildi. Bu dosya o
/// bağlantıyı kurar.
///
/// [auth.dart] ile aynı desen: [supabaseConfigured] false iken (backend
/// yokken) [LocalFriendsService] kullanılır — hiçbir şey çökmez, sadece
/// arkadaş eklenemez.
library;

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'models.dart';

/// Bir arkadaşın profil bilgisi (yalnızca görüntülemek için gereken alanlar).
class FriendProfile {
  final String id;
  final String username;
  const FriendProfile({required this.id, required this.username});
}

enum FriendshipStatus { pending, accepted }

/// Bir arkadaşlık kaydı, geçerli kullanıcı açısından yorumlanmış hali
/// ("karşı taraf" kim, istek gelen mi giden mi).
class FriendshipView {
  final int id;
  final FriendshipStatus status;
  final FriendProfile other;

  /// true: bu istek bana geldi (ben addressee'yim, henüz onaylamadım).
  /// false + pending: ben gönderdim, karşı taraf henüz onaylamadı.
  final bool incoming;

  const FriendshipView({
    required this.id,
    required this.status,
    required this.other,
    required this.incoming,
  });
}

/// Bir arkadaşın paylaşmayı seçtiği tek bir streak özeti (salt okunur).
class SharedStreakSummary {
  final String userId;
  final int id;
  final String name;
  final int startMs;
  final int bestDays;

  const SharedStreakSummary({
    required this.userId,
    required this.id,
    required this.name,
    required this.startMs,
    required this.bestDays,
  });

  /// Streak.days ile aynı mantık (takvim günü bazlı).
  int get days {
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final now = DateTime.now();
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(now.year, now.month, now.day);
    final diff = b.difference(a).inDays;
    return diff > bestDays ? diff : bestDays;
  }
}

/// Bir arkadaşın gönderdiği "şu an zorlanıyorum" sinyali.
class PanicSignal {
  final int id;
  final String userId;
  final String username;
  final String streakName;
  final DateTime createdAt;
  final bool acknowledged;

  const PanicSignal({
    required this.id,
    required this.userId,
    required this.username,
    required this.streakName,
    required this.createdAt,
    required this.acknowledged,
  });

  /// Sinyal ne kadar süre önce gönderildi.
  Duration get age => DateTime.now().difference(createdAt);
}

abstract class FriendsService {
  /// Profilim yoksa oluşturur (benzersiz bir friend_code üretir), varsa
  /// mevcut kodu döndürür. Backend yokken / hata olursa null döner.
  Future<String?> ensureProfile(String username);

  /// Tüm arkadaşlık kayıtlarımı (bekleyen + onaylı, gelen + giden) getirir.
  Future<List<FriendshipView>> loadFriendships();

  /// Bir arkadaşlık kodu ile istek gönderir. Başarılıysa null, değilse
  /// kullanıcıya gösterilecek hata mesajını döndürür.
  Future<String?> sendRequestByCode(String code);

  /// Gelen bir isteği onaylar ya da reddeder (reddetmek = kaydı siler).
  Future<void> respondToRequest(int friendshipId, {required bool accept});

  /// Bir arkadaşlığı kaldırır (giden isteği iptal etmek için de kullanılır).
  Future<void> removeFriendship(int friendshipId);

  /// Bir streak'in paylaşım durumunu sunucuyla senkronlar.
  Future<void> syncSharedStreak(Streak streak, {required bool shared});

  /// Belirtilen kullanıcıların paylaştığı streak özetlerini getirir.
  Future<List<SharedStreakSummary>> loadSharedStreaks(
      List<String> friendUserIds);

  /// "Şu an zorlanıyorum" sinyali gönderir.
  ///
  /// NOT: Anlık push bildirimi GÖNDERMEZ — arkadaş, uygulamayı bir sonraki
  /// açışında görür (bkz. supabase_panic_signals.sql). Arayüz bunu
  /// kullanıcıya açıkça söylemelidir.
  Future<bool> sendPanicSignal(String streakName);

  /// Arkadaşlardan gelen, son 24 saat içindeki sinyalleri getirir.
  Future<List<PanicSignal>> loadPanicSignals();

  /// Bir sinyali "gördüm, yanındayım" olarak işaretler.
  Future<void> acknowledgePanic(int signalId);
}

/// Backend'siz stub — Supabase yapılandırılmamışken kullanılır.
class LocalFriendsService implements FriendsService {
  const LocalFriendsService();

  @override
  Future<String?> ensureProfile(String username) async => null;

  @override
  Future<List<FriendshipView>> loadFriendships() async => const [];

  @override
  Future<String?> sendRequestByCode(String code) async =>
      'Arkadaş eklemek için giriş yapmalısın.';

  @override
  Future<void> respondToRequest(int friendshipId,
      {required bool accept}) async {}

  @override
  Future<void> removeFriendship(int friendshipId) async {}

  @override
  Future<void> syncSharedStreak(Streak streak, {required bool shared}) async {}

  @override
  Future<List<SharedStreakSummary>> loadSharedStreaks(
          List<String> friendUserIds) async =>
      const [];

  @override
  Future<bool> sendPanicSignal(String streakName) async => false;

  @override
  Future<List<PanicSignal>> loadPanicSignals() async => const [];

  @override
  Future<void> acknowledgePanic(int signalId) async {}
}

/// Gerçek Supabase implementasyonu. Yalnızca [supabaseConfigured] true
/// iken kullanılır.
class SupabaseFriendsService implements FriendsService {
  const SupabaseFriendsService();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // O/0/I/1 gibi karıştırılabilecek karakterler dışlandı.
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode(int len) {
    final rnd = Random.secure();
    return List.generate(len, (_) => _codeChars[rnd.nextInt(_codeChars.length)])
        .join();
  }

  @override
  Future<String?> ensureProfile(String username) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final existing = await _client
          .from('profiles')
          .select('friend_code')
          .eq('id', uid)
          .maybeSingle();
      if (existing != null) return existing['friend_code'] as String?;
    } catch (_) {
      // Sorgu başarısız oldu (ör. RLS henüz hazır değil) — oluşturmayı dene.
    }
    for (var i = 0; i < 5; i++) {
      final code = _randomCode(6);
      try {
        await _client.from('profiles').insert({
          'id': uid,
          'username': username.isEmpty ? 'Rutin' : username,
          'friend_code': code,
        });
        return code;
      } on PostgrestException catch (e) {
        if (e.code == '23505') continue; // kod çakıştı, tekrar üret
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<List<FriendshipView>> loadFriendships() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('friendships')
        .select()
        .or('requester.eq.$uid,addressee.eq.$uid');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];

    final otherIds = list
        .map((r) => (r['requester'] as String) == uid
            ? r['addressee'] as String
            : r['requester'] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('profiles')
        .select('id, username')
        .inFilter('id', otherIds);
    final byId = {
      for (final p in (profiles as List).cast<Map<String, dynamic>>())
        p['id'] as String: p['username'] as String
    };

    return list.map((r) {
      final requesterId = r['requester'] as String;
      final addresseeId = r['addressee'] as String;
      final otherId = requesterId == uid ? addresseeId : requesterId;
      return FriendshipView(
        id: r['id'] as int,
        status: (r['status'] as String) == 'accepted'
            ? FriendshipStatus.accepted
            : FriendshipStatus.pending,
        other: FriendProfile(id: otherId, username: byId[otherId] ?? '—'),
        incoming: addresseeId == uid,
      );
    }).toList();
  }

  @override
  Future<String?> sendRequestByCode(String code) async {
    final uid = _uid;
    if (uid == null) return 'Önce giriş yapmalısın.';
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return 'Bir kod gir.';
    try {
      final target = await _client
          .from('profiles')
          .select('id')
          .eq('friend_code', normalized)
          .maybeSingle();
      if (target == null) return 'Bu kodla eşleşen kullanıcı bulunamadı.';
      final targetId = target['id'] as String;
      if (targetId == uid) return 'Kendini ekleyemezsin 🙂';

      final existing = await _client
          .from('friendships')
          .select('id')
          .or('and(requester.eq.$uid,addressee.eq.$targetId),'
              'and(requester.eq.$targetId,addressee.eq.$uid)')
          .maybeSingle();
      if (existing != null) {
        return 'Zaten arkadaşsınız ya da bekleyen bir istek var.';
      }

      await _client.from('friendships').insert({
        'requester': uid,
        'addressee': targetId,
        'status': 'pending',
      });
      return null;
    } on PostgrestException catch (_) {
      return 'İstek gönderilemedi.';
    } catch (_) {
      return 'İstek gönderilemedi.';
    }
  }

  @override
  Future<void> respondToRequest(int friendshipId,
      {required bool accept}) async {
    if (accept) {
      await _client
          .from('friendships')
          .update({'status': 'accepted'}).eq('id', friendshipId);
    } else {
      await _client.from('friendships').delete().eq('id', friendshipId);
    }
  }

  @override
  Future<void> removeFriendship(int friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  @override
  Future<void> syncSharedStreak(Streak streak, {required bool shared}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      if (shared) {
        await _client.from('shared_streaks').upsert({
          'id': streak.id,
          'user_id': uid,
          'name': streak.name,
          'start_ms': streak.start.millisecondsSinceEpoch,
          'best_days': streak.daysOrBest,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _client
            .from('shared_streaks')
            .delete()
            .eq('user_id', uid)
            .eq('id', streak.id);
      }
    } catch (_) {
      // Senkronizasyon başarısız olsa bile yerel toggle zaten uygulandı;
      // kullanıcı akışı kesilmez, bir sonraki senkronizasyonda düzelir.
    }
  }

  @override
  Future<List<SharedStreakSummary>> loadSharedStreaks(
      List<String> friendUserIds) async {
    if (friendUserIds.isEmpty) return const [];
    final rows = await _client
        .from('shared_streaks')
        .select()
        .inFilter('user_id', friendUserIds);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => SharedStreakSummary(
              userId: r['user_id'] as String,
              id: r['id'] as int,
              name: r['name'] as String,
              startMs: r['start_ms'] as int,
              bestDays: (r['best_days'] ?? 0) as int,
            ))
        .toList();
  }

  @override
  Future<bool> sendPanicSignal(String streakName) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('panic_signals').insert({
        'user_id': uid,
        'streak_name': streakName,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PanicSignal>> loadPanicSignals() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      // Son 24 saat: daha eski bir sinyal artık "şu an zorlanıyorum"
      // anlamına gelmez ve göstermek yanıltıcı olur.
      final since = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toUtc()
          .toIso8601String();
      final rows = await _client
          .from('panic_signals')
          .select('id, user_id, streak_name, created_at, acknowledged_at')
          .neq('user_id', uid) // kendi sinyalimi bana gösterme
          .gte('created_at', since)
          .order('created_at', ascending: false);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return const [];

      // Gönderenlerin kullanıcı adlarını tek sorguda çek.
      final ids = list.map((r) => r['user_id'] as String).toSet().toList();
      final profiles = await _client
          .from('profiles')
          .select('id, username')
          .inFilter('id', ids);
      final names = <String, String>{
        for (final p in (profiles as List).cast<Map<String, dynamic>>())
          p['id'] as String: (p['username'] ?? '') as String,
      };

      return list
          .map((r) => PanicSignal(
                id: r['id'] as int,
                userId: r['user_id'] as String,
                username: names[r['user_id']] ?? '',
                streakName: (r['streak_name'] ?? '') as String,
                createdAt:
                    DateTime.parse(r['created_at'] as String).toLocal(),
                acknowledged: r['acknowledged_at'] != null,
              ))
          .toList();
    } catch (_) {
      // Tablo henüz oluşturulmamış olabilir (supabase_panic_signals.sql
      // çalıştırılmadıysa) — özellik sessizce devre dışı kalır, arkadaş
      // ekranı normal çalışmaya devam eder.
      return const [];
    }
  }

  @override
  Future<void> acknowledgePanic(int signalId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('panic_signals').update({
        'acknowledged_by': uid,
        'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', signalId);
    } catch (_) {
      // Yok sayılır.
    }
  }
}

/// Uygulamanın kullandığı arkadaş servisi. Supabase yapılandırılmışsa
/// gerçek [SupabaseFriendsService], değilse backend'siz [LocalFriendsService].
FriendsService get friendsService => supabaseConfigured
    ? const SupabaseFriendsService()
    : const LocalFriendsService();
