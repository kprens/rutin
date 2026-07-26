import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics.dart';
import '../auth.dart';
import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'root_shell.dart';

/// Giriş / kayıt ekranı.
///
/// Kimlik doğrulama [authService] (auth.dart) üzerinden yapılır — bugün
/// backend'siz [LocalAuthService], yarın `SupabaseAuthService`. Bu ekran
/// yalnızca [AuthService] arayüzünü tanır; Supabase eklenince burası
/// değişmez.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  AuthMode _mode = AuthMode.signUp;
  bool _busy = false;

  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ---------- Doğrulama ----------

  /// Girdileri kontrol eder; hata mesajı döndürür, geçerliyse null.
  String? _validate() {
    final email = _email.text.trim();
    final pass = _password.text;
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) {
      return t('Geçerli bir e-posta gir.', 'Enter a valid email.');
    }
    if (pass.length < 6) {
      return t('Parola en az 6 karakter olmalı.',
          'Password must be at least 6 characters.');
    }
    return null;
  }

  // ---------- Akış ----------

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      _toast(err);
      return;
    }
    await _run(() => _isSignUp
        ? authService.signUp(
            email: _email.text.trim(),
            password: _password.text,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          )
        : authService.signIn(
            email: _email.text.trim(),
            password: _password.text,
          ));
  }

  Future<void> _oauth(Future<AuthResult> Function() call,
          {required String method}) =>
      _run(call, method: method);

  /// Ortak yürütücü: yükleniyor durumunu yönetir, sonucu işler, başarılıysa
  /// onboarding'i tamamlayıp ana ekrana geçer.
  Future<void> _run(Future<AuthResult> Function() call,
      {String method = 'email'}) async {
    if (_busy) return;
    // AppState referansı HER await'ten ÖNCE yakalanıyor.
    //
    // Alternatif (await sonrası `context.read`) iki sorun doğuruyordu:
    // widget bu sırada ağaçtan kalkmışsa context kullanımı geçersiz olur;
    // `mounted` kontrolüyle atlamak ise `onSignedIn()`'in HİÇ çalışmaması
    // demektir — yani kullanıcının bulut verisi yüklenmez. Referansı önden
    // almak ikisini de çözüyor: state işi mount durumundan bağımsız tamamlanır,
    // yalnızca ARAYÜZ dokunuşları mounted ile korunur.
    final state = context.read<AppState>();
    setState(() => _busy = true);
    Analytics.instance
        .log(Ev.authStart, {'method': method, 'mode': _isSignUp ? 'signup' : 'signin'});
    final result = await call();
    if (!result.ok) {
      // Hata METNİ gönderilmez (sağlayıcıya göre değişen serbest metin,
      // e-posta içerebilir); yalnızca iptal mi gerçek hata mı ayrımı.
      Analytics.instance.log(Ev.authFail, {
        'method': method,
        'reason': (result.error ?? '').isEmpty ? 'cancelled' : 'error',
      });
      if (!mounted) return;
      setState(() => _busy = false);
      // Boş hata mesajı = kullanıcı akışı kendi iptal etti (ör. Apple giriş
      // sayfasını kapattı). Bu bir arıza değil; uyarı göstermek kullanıcıyı
      // yaptığı şey yanlışmış gibi hissettirir.
      final msg = result.error;
      if (msg != null && msg.isEmpty) return;
      _toast(msg ?? t('Bir şeyler ters gitti.', 'Something went wrong.'));
      return;
    }
    Analytics.instance.log(Ev.authSuccess,
        {'method': method, 'mode': _isSignUp ? 'signup' : 'signin'});
    // Bu hesabın bulutta kayıtlı verisi varsa yükler (cihazdaki önceki
    // oturuma ait veri tamamen değiştirilir); yoksa şu anki cihaz verisini
    // bu hesaba ilk kez taşır. Backend yapılandırılmamışsa no-op.
    await state.onSignedIn();
    // Backend yokken de kullanıcıyı yerelde kurar; Supabase geldiğinde
    // oturum zaten açılmış olur, bu satır profil adını yazmaya devam eder.
    state.finishOnboarding(name: _name.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RootShell()));
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1C1B3A), RC.bg],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: RG.purpleBtn,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: RC.purple.withValues(alpha: 0.5),
                          blurRadius: 28),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                  child: Text(
                      _isSignUp
                          ? t('Hesap oluştur', 'Create account')
                          : t('Tekrar hoş geldin', 'Welcome back'),
                      style: RText.h2)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                    _isSignUp
                        ? t('Dönüşümüne bugün başla',
                            'Start your transformation today')
                        : t('Kaldığın yerden devam et',
                            'Pick up where you left off'),
                    style: RText.muted),
              ),
              const SizedBox(height: 36),

              // Ad yalnızca kayıtta gerekir.
              if (_isSignUp) ...[
                _field(_name, t('Ad Soyad', 'Full name')),
                const SizedBox(height: 14),
              ],
              _field(_email, t('E-posta adresi', 'Email address'),
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _field(_password, t('Parola', 'Password'), obscure: true),
              const SizedBox(height: 24),

              _busy
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            color: RC.purpleBright),
                      ),
                    )
                  : RButton(
                      _isSignUp
                          ? t('Hesap Oluştur', 'Create Account')
                          : t('Giriş Yap', 'Sign In'),
                      onTap: _submit),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: RC.stroke)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t('veya şununla devam et', 'or continue with'),
                        style: TextStyle(color: RC.muted, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: RC.stroke)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _social(Icons.g_mobiledata, 'Google',
                          () => _oauth(authService.signInWithGoogle,
                              method: 'google'))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _social(Icons.apple, 'Apple',
                          () => _oauth(authService.signInWithApple,
                              method: 'apple'))),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _busy
                      ? null
                      : () => setState(() => _mode =
                          _isSignUp ? AuthMode.signIn : AuthMode.signUp),
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: _isSignUp
                              ? t('Zaten hesabın var mı? ',
                                  'Already have an account? ')
                              : t('Hesabın yok mu? ', "Don't have an account? "),
                          style:
                              TextStyle(color: RC.muted, fontSize: 14)),
                      TextSpan(
                          text: _isSignUp
                              ? t('Giriş yap', 'Sign in')
                              : t('Kayıt ol', 'Sign up'),
                          style: TextStyle(
                              color: RC.purpleBright,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      style: TextStyle(color: RC.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: RC.muted),
        filled: true,
        fillColor: RC.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RC.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RC.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RC.purple),
        ),
      ),
    );
  }

  Widget _social(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RC.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.stroke),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: RC.text),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: RC.text, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      );
}
