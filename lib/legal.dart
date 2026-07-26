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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

/// Yayınlanmış yasal sayfaların kök adresi (bkz. MAGAZA-VERI-GUVENLIGI.md —
/// her iki mağaza formuna da bu adres girilmiştir).
const String kLegalBaseUrl = 'https://kprens.github.io/rutin-legal';

const String kPrivacyPolicyUrl = kLegalBaseUrl;
const String kTermsOfUseUrl = '$kLegalBaseUrl/kullanim-kosullari';
const String kDeleteAccountUrl = '$kLegalBaseUrl/hesap-silme';

/// Apple'ın standart EULA'sı — kendi kullanım koşulunu yayınlamayan
/// uygulamalar için App Store'un kabul ettiği adres.
const String kAppleStandardEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

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
