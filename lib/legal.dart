/// Yasal bağlantılar (gizlilik politikası, kullanım koşulları, hesap silme).
///
/// Bu bağlantılar ZORUNLUDUR, kozmetik değildir:
///   • App Store Review Guideline 3.1.2 — abonelik satılan ekranda (paywall)
///     kullanım koşulları (EULA) ve gizlilik politikası bağlantısı bulunmalı.
///   • App Store Review Guideline 5.1.1 — gizlilik politikası uygulama
///     içinden erişilebilir olmalı.
///   • Google Play — gizlilik politikası bağlantısı zorunlu.
/// Uygulamada bu bağlantıların HİÇBİRİ yoktu; bu tek başına mağaza reddi
/// sebebidir.
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

/// Yayınlanmış yasal sayfaların kök adresi (bkz. MAGAZA-VERI-GUVENLIGI.md —
/// her iki mağaza formuna da bu adres girilmiştir).
const String kLegalBaseUrl = 'https://kprens.github.io/rutin-legal';

const String kPrivacyPolicyUrl = kLegalBaseUrl;

/// Hesap silme açıklaması — gizlilik politikasının İÇİNDEKİ bölüme gider.
///
/// Daha önce `$kLegalBaseUrl/hesap-silme` idi ve **404 dönüyordu**: böyle bir
/// sayfa hiç yayınlanmamış. İçerik aslında var, gizlilik politikasının bir
/// bölümü olarak; bu yüzden doğru adres o bölümün anchor'ı.
const String kDeleteAccountUrl = '$kLegalBaseUrl/#hesap-silme';

/// Apple'ın standart EULA'sı — kendi kullanım koşulunu yayınlamayan
/// uygulamalar için App Store'un kabul ettiği adres.
const String kAppleStandardEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Kullanım koşulları.
///
/// DURUM: `$kLegalBaseUrl/kullanim-kosullari` **404 dönüyor** — böyle bir sayfa
/// hiç yayınlanmamış, içerik de yazılmamış. Bu bağlantı paywall'da duruyor ve
/// App Store Review Guideline 3.1.2 tam olarak orada çalışan bir EULA
/// bağlantısı istiyor; 404 doğrudan ret sebebi.
///
/// GEÇİCİ ÇÖZÜM (iOS): Apple, kendi EULA'sını yayınlamayan geliştiricilerin
/// standart EULA'sına bağlanmasını AÇIKÇA kabul eder. Yani iOS tarafı bu
/// haliyle kurallara uygun.
///
/// DİĞER PLATFORMLAR: Play, kullanım koşulunu zorunlu tutmuyor (gizlilik
/// politikası zorunlu ve o yayında). Apple'ın EULA'sı App Store'a atıf yaptığı
/// için Android'de göstermek yanlış olurdu; bu yüzden orada yayındaki yasal
/// sayfanın köküne gidiliyor.
///
/// KALICI ÇÖZÜM: `rutin-legal` deposunda gerçek bir kullanım koşulları sayfası
/// yayınlanmalı ve burası oraya çevrilmeli. O zamana kadar bu, 404'ten iyi
/// ama ideal değil.
/// (`dart:io` Platform DEĞİL — proje web'i de hedefliyor, orada derlenmez.)
String get kTermsOfUseUrl =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ? kAppleStandardEulaUrl
        : kLegalBaseUrl;

/// Bağlantıyı harici tarayıcıda açar. Açılamazsa kullanıcıya sessiz
/// kalmak yerine kısa bir bilgi gösterilir — "dokundum, hiçbir şey olmadı"
/// deneyimi güven kaybettirir.
Future<void> openLegalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t('Bağlantı açılamadı: $url', 'Couldn\'t open: $url')),
      ));
  }
}
