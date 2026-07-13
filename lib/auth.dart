/// Kimlik doğrulama soyutlaması — Supabase'e hazır seam.
///
/// Bugün [LocalAuthService] kullanılıyor: gerçek backend YOK, her giriş
/// yerelde başarılı sayılır ve onboarding tamamlanır. Supabase eklendiğinde
/// tek yapılacak, aynı [AuthService] arayüzünü uygulayan bir
/// `SupabaseAuthService` yazıp `authService` sabitini değiştirmek — ekran
/// koduna (auth_screen.dart) dokunmadan.
///
/// Bu, projedeki [Repository] (repository.dart) deseninin aynısıdır.
library;

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
}

/// Backend'siz yerel stub. Girişleri her zaman başarılı sayar; gerçek
/// doğrulama Supabase eklendiğinde devreye girer.
///
/// Supabase'e geçiş (referans):
/// ```dart
/// // main.dart bootRutin() içinde:
/// //   await Supabase.initialize(url: ..., anonKey: ...);
/// //
/// // class SupabaseAuthService implements AuthService {
/// //   final _c = Supabase.instance.client;
/// //   Future<AuthResult> signUp({required email, required password, name}) async {
/// //     try {
/// //       await _c.auth.signUp(email: email, password: password,
/// //           data: {'name': name});
/// //       return const AuthResult.success();
/// //     } on AuthException catch (e) {
/// //       return AuthResult.failure(e.message);
/// //     }
/// //   }
/// //   ... signIn / signInWithGoogle (OAuthProvider.google) / signInWithApple ...
/// // }
/// ```
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
}

/// Uygulamanın kullandığı auth servisi. Supabase geldiğinde bu satır
/// `const SupabaseAuthService()` olur; başka hiçbir yeri değiştirmeye gerek yok.
const AuthService authService = LocalAuthService();
