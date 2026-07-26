/// Kimlik doğrulama soyutlaması.
///
/// [supabaseConfigured] `true` ise (main.dart, `SUPABASE_URL` +
/// `SUPABASE_ANON_KEY` --dart-define'ları ile `Supabase.initialize` çağırıp
/// başarılı olduysa ayarlar) gerçek [SupabaseAuthService] kullanılır.
/// Yapılandırılmamışsa backend'siz [LocalAuthService]'e düşülür — her giriş
/// yerelde başarılı sayılır, uygulama çökmeden çalışmaya devam eder.
///
/// Ekran kodu (auth_screen.dart) yalnızca [AuthService] arayüzünü tanır,
/// hangi implementasyonun aktif olduğuyla ilgilenmez.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google/Apple OAuth tamamlandığında tarayıcının uygulamaya geri döneceği
/// adres. AndroidManifest.xml'deki intent-filter (scheme=com.alper.rutin,
/// host=login-callback) ile birebir eşleşmeli. Ayrıca Supabase Dashboard →
/// Authentication → URL Configuration → Redirect URLs listesine de EKLENMELİ
/// — aksi halde Supabase bu adrese yönlendirmeyi reddeder.
const String _oauthRedirectUrl = 'com.alper.rutin://login-callback';

/// Kayıt (sign up) mı, giriş (sign in) mi.
enum AuthMode { signUp, signIn }

/// Bir auth çağrısının sonucu. [ok] false ise [error] kullanıcıya gösterilir.
class AuthResult {
  final bool ok;
  final String? error;

  const AuthResult.success() : ok = true, error = null;
  const AuthResult.failure(this.error) : ok = false;
}

/// Uygulamanın kimlik doğrulama arayüzü. Ekran yalnızca bunu tanır.
abstract class AuthService {
  /// E-posta + parola ile kayıt.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  });

  /// E-posta + parola ile giriş.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  });

  /// Google ile OAuth.
  Future<AuthResult> signInWithGoogle();

  /// Apple ile OAuth (iOS'ta zorunlu — sosyal giriş sunuluyorsa).
  Future<AuthResult> signInWithApple();

  /// Oturum kapatma (bulut oturumu; yerel veri ayrı temizlenir).
  Future<void> signOut();

  /// Sunucu tarafı hesabı kalıcı olarak siler (Google Play & App Store
  /// zorunluluğu: uygulama içi hesap silme, bulut hesabını da silmeli).
  /// Yerel veri ayrıca AppState.wipeAllData() ile temizlenir.
  ///
  /// SUNUCUDAKİ silme başarılıysa `true` döner. `false` dönmesi, cihazdaki
  /// verinin silindiği ama BULUTTAKİ hesabın hâlâ durduğu anlamına gelir ve
  /// kullanıcıya mutlaka bildirilmelidir — aksi halde uygulama, App Store
  /// 5.1.1(v)'in talep ettiği silmeyi yapmadığı hâlde yapmış gibi görünür.
  Future<bool> deleteAccount();
}

/// Backend'siz yerel stub. Girişleri her zaman başarılı sayar.
/// [supabaseConfigured] false iken (Supabase yapılandırılmamışken) kullanılır.
class LocalAuthService implements AuthService {
  const LocalAuthService();

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  }) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async =>
      const AuthResult.success();

  @override
  Future<AuthResult> signInWithGoogle() async => const AuthResult.success();

  @override
  Future<AuthResult> signInWithApple() async => const AuthResult.success();

  @override
  Future<void> signOut() async {}

  /// Backend yok — silinecek sunucu hesabı da yok, dolayısıyla başarılı.
  @override
  Future<bool> deleteAccount() async => true;
}

/// main.dart, `Supabase.initialize` başarıyla tamamlandığında bunu `true`
/// yapar. O ana kadar (ör. dart-define verilmediyse) `false` kalır ve
/// [authService] [LocalAuthService]'e düşer.
bool supabaseConfigured = false;

/// Gerçek Supabase Auth implementasyonu (e-posta/parola + Google/Apple OAuth).
/// Yalnızca [supabaseConfigured] true iken kullanılır — aksi halde
/// `Supabase.instance.client` henüz başlatılmamış olabilir.
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: name == null || name.isEmpty ? null : {'name': name},
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure(
          'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure(
          'Giriş sırasında bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() => _oauthSignIn(
        OAuthProvider.google,
        'Google',
      );

  /// Apple ile giriş.
  ///
  /// iOS'ta YEREL akış kullanılır (cihazdaki Apple hesabı, Face ID/Touch ID
  /// ile onay). Android'de böyle bir yerel akış yoktur; orada tarayıcı
  /// tabanlı OAuth doğru olandır.
  ///
  /// Neden ayrım şart: iOS'ta tarayıcı akışı hem güvenilir çalışmıyor
  /// (kullanıcı zaten cihazında Apple hesabıyla oturum açmışken tarayıcıya
  /// atılıp tekrar şifre girmesi bekleniyor, geri dönüş deep link'e bağlı ve
  /// kırılgan) hem de App Store incelemesinde beklenen davranış değil.
  @override
  Future<AuthResult> signInWithApple() {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return isIos ? _nativeAppleSignIn() : _oauthSignIn(OAuthProvider.apple, 'Apple');
  }

  /// iOS yerel Apple girişi.
  ///
  /// Akış: rastgele bir nonce üret → SHA-256 özetini Apple'a ver → Apple'ın
  /// döndürdüğü identity token'ı, HAM nonce ile birlikte Supabase'e ver.
  /// Nonce, token'ın araya girilerek yeniden kullanılmasını (replay attack)
  /// engeller; Supabase ham nonce'u hash'leyip token içindekiyle karşılaştırır.
  Future<AuthResult> _nativeAppleSignIn() async {
    try {
      final rawNonce = _randomNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return const AuthResult.failure(
            'Apple kimlik doğrulaması tamamlanamadı. Lütfen tekrar deneyin.');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Apple, adı YALNIZCA ilk girişte gönderir. Kaçırılırsa bir daha
      // alınamaz — bu yüzden hemen profile yazılır.
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName = [given, family].where((p) => p.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        try {
          await _client.auth.updateUser(UserAttributes(data: {'name': fullName}));
        } catch (_) {
          // İsim kaydedilemedi; giriş yine de başarılı.
        }
      }

      return const AuthResult.success();
    } on SignInWithAppleAuthorizationException catch (e) {
      // Kullanıcı vazgeçtiyse hata gösterme — bu bir arıza değil.
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.failure('');
      }
      return const AuthResult.failure(
          'Apple ile giriş yapılamadı. Lütfen tekrar deneyin.');
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (_) {
      return const AuthResult.failure('Apple ile giriş başarısız oldu.');
    }
  }

  /// Apple'ın istediği kriptografik nonce (yalnızca URL-güvenli karakterler).
  String _randomNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Tarayıcı tabanlı OAuth akışını başlatır ve gerçek oturum açılana kadar
  /// bekler.
  ///
  /// ÖNEMLİ: `signInWithOAuth` yalnızca tarayıcının başarıyla açıldığını
  /// bildirir (true/false) — kullanıcının girişi TAMAMLADIĞINI göstermez.
  /// Önceki kod bu Future'ı beklediği an "başarılı" sayıp kullanıcıyı ana
  /// ekrana geçiriyordu; bu yüzden gerçekte oturum açılmadan (kullanıcı
  /// tarayıcıda hiçbir şey yapmadan) girişin tamamlanmış gibi görünmesine
  /// (ve tarayıcıdan uygulamaya dönüşün de deep link eksikliğinden hiç
  /// çalışmamasına) yol açıyordu. Burada `onAuthStateChange` akışını
  /// dinleyip gerçek `signedIn` olayını (ya da zaman aşımını) bekliyoruz.
  Future<AuthResult> _oauthSignIn(OAuthProvider provider, String label) async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectUrl,
      );
      if (!launched) {
        return AuthResult.failure('$label ile giriş başlatılamadı.');
      }
      final state = await _client.auth.onAuthStateChange
          .firstWhere((s) => s.event == AuthChangeEvent.signedIn)
          .timeout(const Duration(minutes: 2));
      return state.session != null
          ? const AuthResult.success()
          : AuthResult.failure('$label ile giriş tamamlanamadı.');
    } on TimeoutException {
      return AuthResult.failure(
          '$label ile giriş zaman aşımına uğradı. Lütfen tekrar deneyin.');
    } catch (_) {
      return AuthResult.failure('$label ile giriş başarısız oldu.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Yerel oturum zaten AppState.signOut() tarafından temizleniyor;
      // bulut çağrısı başarısız olsa da kullanıcı akışı kesilmemeli.
    }
  }

  @override
  Future<bool> deleteAccount() async {
    // Sunucudaki hesabı siler (supabase_delete_user.sql → public.delete_user).
    // Fonksiyon security definer'dır ve yalnızca auth.uid()'nin kendi
    // kaydını siler.
    //
    // Oturum yoksa silinecek bir sunucu hesabı da yoktur — bu bir hata
    // değil, başarı sayılır.
    if (_client.auth.currentSession == null) return true;

    var serverDeleted = false;
    try {
      await _client.rpc('delete_user');
      serverDeleted = true;
    } catch (_) {
      // RPC kurulu değilse / ağ yoksa yerel temizlik yine de devam eder,
      // ama sonuç `false` döner ki kullanıcıya "hesabın tamamen silindi"
      // gibi YANLIŞ bir bilgi verilmesin.
      serverDeleted = false;
    }
    try {
      await _client.auth.signOut();
    } catch (_) {}
    return serverDeleted;
  }
}

/// Uygulamanın kullandığı auth servisi. Supabase yapılandırılmışsa gerçek
/// [SupabaseAuthService], değilse backend'siz [LocalAuthService].
AuthService get authService =>
    supabaseConfigured ? const SupabaseAuthService() : const LocalAuthService();
