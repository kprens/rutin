/// Uygulama sürümü — TEK KAYNAK burası.
///
/// Yeni bir sürüm yayınlarken:
/// 1) Bu sabiti güncelle.
/// 2) `pubspec.yaml`'daki `version:` alanını AYNI sürüm numarasıyla
///    güncelle (mağaza build'leri `CFBundleShortVersionString` /
///    `versionName`'i pubspec'ten türetir — Dart tarafı bu sabitten okur).
///
/// UI'da kullanım: `lib/ui/settings_screen.dart` ve
/// `lib/ui/profile_screen.dart` → "Rutin v$kAppVersion".
library;

const String kAppVersion = '1.0.0';
