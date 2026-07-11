/// Sosyal katman — Supabase üzerinden hesap, arkadaşlar ve
/// paylaşılan streak özetleri.
///
/// Gizlilik ilkesi: kullanıcının verisi cihazında kalır; buluta yalnızca
/// paylaşmayı SEÇTİĞİ streak'lerin özeti (isim + başlangıç + en iyi seri)
/// gönderilir.
library;

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n.dart';
import 'models.dart';

class SocialConfig {
  static const url = 'https://pfgljdvkmkqvlvdljvjk.supabase.co';
  static const anonKey = 'sb_publishable__kjLS-R4JSWrzhbb6sDSOQ_9Kz-5nb_';
}

class FriendStreak {
  final String name;
  final DateTime start;
  final int bestDays;

  FriendStreak({required this.name, required this.start, required this.bestDays});

  int get days {
    final now = DateTime.now();
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }
}

class FriendEntry {
  final String userId;
  final String username;
  final bool isMe;
  final List<FriendStreak> streaks;

  FriendEntry({
    required this.userId,
    required this.username,
    required this.isMe,
    required this.streaks,
  });

  int get topDays => streaks.fold(0, (a, s) => s.days > a ? s.days : a);
}

class FriendRequest {
  final int id;
  final String username;

  FriendRequest({required this.id, required this.username});
}

class Social {
  static SupabaseClient get _db => Supabase.instance.client;

  static User? get user => _db.auth.currentUser;
  static bool get signedIn => user != null;

  static Future<void> init() async {
    await Supabase.initialize(
        url: SocialConfig.url, anonKey: SocialConfig.anonKey);
  }

  // ---------- Hesap ----------

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // karışan karakterler yok
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<void> signUp(
      String email, String password, String username) async {
    final res = await _db.auth.signUp(email: email, password: password);
    final uid = res.user?.id;
    if (uid == null) throw t('Kayıt başarısız oldu.', 'Sign-up failed.');
    await _db.from('profiles').insert({
      'id': uid,
      'username': username,
      'friend_code': _genCode(),
    });
  }

  static Future<void> signIn(String email, String password) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _db.auth.signOut();

  /// Hesabı kalıcı olarak siler (Play Store zorunluluğu).
  /// Veritabanındaki `delete_user` fonksiyonunu çağırır; profil,
  /// arkadaşlıklar ve paylaşılan streak'ler cascade ile silinir.
  static Future<void> deleteAccount() async {
    await _db.rpc('delete_user');
    await _db.auth.signOut();
  }

  static Future<Map<String, dynamic>?> myProfile() async {
    final uid = user?.id;
    if (uid == null) return null;
    return await _db.from('profiles').select().eq('id', uid).maybeSingle();
  }

  // ---------- Arkadaşlık ----------

  static Future<String> addFriendByCode(String code) async {
    final uid = user!.id;
    final target = await _db
        .from('profiles')
        .select()
        .eq('friend_code', code.trim().toUpperCase())
        .maybeSingle();
    if (target == null) return t('Bu koda sahip kullanıcı bulunamadı.', 'No user found with this code.');
    if (target['id'] == uid) return t('Bu senin kendi kodun 🙂', "That's your own code 🙂");
    try {
      await _db.from('friendships').insert({
        'requester': uid,
        'addressee': target['id'],
      });
      return t('İstek gönderildi: ${target['username']} 🎉', 'Request sent: ${target['username']} 🎉');
    } catch (_) {
      return t('Zaten istek gönderilmiş veya arkadaşsınız.', 'Request already sent, or you are already friends.');
    }
  }

  static Future<List<FriendRequest>> pendingRequests() async {
    final uid = user!.id;
    final rows = await _db
        .from('friendships')
        .select('id, requester')
        .eq('addressee', uid)
        .eq('status', 'pending');
    final result = <FriendRequest>[];
    for (final r in rows) {
      final p = await _db
          .from('profiles')
          .select('username')
          .eq('id', r['requester'])
          .maybeSingle();
      result.add(FriendRequest(
          id: r['id'] as int,
          username: (p?['username'] ?? t('Bilinmeyen', 'Unknown')) as String));
    }
    return result;
  }

  static Future<void> acceptRequest(int id) async {
    await _db.from('friendships').update({'status': 'accepted'}).eq('id', id);
  }

  static Future<void> declineRequest(int id) async {
    await _db.from('friendships').delete().eq('id', id);
  }

  // ---------- Başarı listesi ----------

  static Future<List<FriendEntry>> leaderboard(String myUsername) async {
    final uid = user!.id;
    final rows = await _db
        .from('friendships')
        .select('requester, addressee')
        .eq('status', 'accepted');

    final friendIds = <String>{};
    for (final r in rows) {
      if (r['requester'] == uid) friendIds.add(r['addressee'] as String);
      if (r['addressee'] == uid) friendIds.add(r['requester'] as String);
    }

    final allIds = [uid, ...friendIds];
    final profiles =
        await _db.from('profiles').select().inFilter('id', allIds);
    final streaks =
        await _db.from('shared_streaks').select().inFilter('user_id', allIds);

    final entries = <FriendEntry>[];
    for (final p in profiles) {
      final userStreaks = streaks
          .where((s) => s['user_id'] == p['id'])
          .map((s) => FriendStreak(
                name: s['name'] as String,
                start: DateTime.fromMillisecondsSinceEpoch(
                    (s['start_ms'] as num).toInt()),
                bestDays: (s['best_days'] ?? 0) as int,
              ))
          .toList()
        ..sort((a, b) => b.days.compareTo(a.days));
      entries.add(FriendEntry(
        userId: p['id'] as String,
        username: p['username'] as String,
        isMe: p['id'] == uid,
        streaks: userStreaks,
      ));
    }
    entries.sort((a, b) => b.topDays.compareTo(a.topDays));
    return entries;
  }

  // ---------- Streak paylaşımı ----------

  /// Paylaşım listesini bulutla eşitler: seçilenler gönderilir,
  /// seçimden çıkarılanlar buluttan silinir.
  static Future<void> syncSharedStreaks(
      List<Streak> all, Set<int> sharedIds) async {
    final uid = user?.id;
    if (uid == null) return;

    final shared = all.where((s) => sharedIds.contains(s.id)).toList();
    if (shared.isNotEmpty) {
      await _db.from('shared_streaks').upsert(shared
          .map((s) => {
                'id': s.id,
                'user_id': uid,
                'name': s.name,
                'start_ms': s.start.millisecondsSinceEpoch,
                'best_days': s.bestDays,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList());
    }
    // Paylaşımdan kaldırılanları temizle
    final keepIds = shared.map((s) => s.id).toList();
    var q = _db.from('shared_streaks').delete().eq('user_id', uid);
    if (keepIds.isNotEmpty) {
      await q.not('id', 'in', '(${keepIds.join(',')})');
    } else {
      await q;
    }
  }
}
