/// Veri deposu soyutlaması.
///
/// Uygulama veriyi bu arayüz üzerinden okur/yazar. Bugün
/// [LocalRepository] (cihazda shared_preferences) kullanılıyor.
/// Sosyal katman geldiğinde aynı arayüzü uygulayan bir
/// `CloudRepository` (Firebase/Supabase) yazılır ve tek satırla
/// değiştirilir — ekran kodlarına dokunmadan.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class Repository {
  Future<Map<String, dynamic>?> loadAll();
  Future<void> saveAll(Map<String, dynamic> data);
}

class LocalRepository implements Repository {
  static const _key = 'rutinData';

  @override
  Future<Map<String, dynamic>?> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveAll(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }
}
