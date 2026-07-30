// Rutin — paywall plan görünürlüğü testleri.
//
// GERÇEK OLAY: App Store Connect'te aylık aboneliğin Product ID'si sonunda
// NOKTA ile oluşturulmuş (`rutin_pro_monthly_v2.`) ve StoreKit bu ürünü
// sunmuyor. Apple oluşturulmuş bir Product ID'yi değiştirmeye de izin
// vermiyor — yani o ürün kalıcı olarak ölü.
//
// Eski kodda paywall koşulu `yearly != null && monthly != null` idi: İKİSİ
// birden gerekiyordu. Sonuç, tek bir bozuk ürünün TÜM satın alma ekranını
// kilitlemesi oldu; yıllık plan sorunsuz gelmesine rağmen kullanıcı hiçbir
// şey satın alamıyordu. App Store bunu 2.1(b) altında reddetti:
// "an error is shown when trying to access the in-app purchases".
//
// Buradaki testler o davranışın geri gelmesini engeller: eksik ürün
// gizlenir, gelen ürünler satılabilir kalır.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/iap.dart';
import 'package:rutin/ui/paywall_screen.dart';

void main() {
  group('resolvePaywallPlans — eksik ürün tüm ekranı kilitlemez', () {
    test('üç ürün de gelirse üçü de gösterilir', () {
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        hasLifetime: true,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, hasLength(3));
      expect(r.selected, Iap.yearlyId);
    });

    test('AYLIK gelmezse yıllık satılabilir kalır — 2.1(b) reddinin senaryosu',
        () {
      // Üretimdeki durum birebir: aylık kimlik servis edilemiyor.
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: false,
        hasLifetime: false,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.yearlyId],
          reason: 'yıllık plan gösterilmeye devam etmeli');
      expect(r.selected, Iap.yearlyId);
    });

    test('YILLIK gelmezse seçim aylığa taşınır', () {
      // Varsayılan seçim yıllıktır; o gelmezse seçim boşta kalamaz, aksi
      // halde satın alma butonu var olmayan bir ürünü hedefler.
      final r = resolvePaywallPlans(
        hasYearly: false,
        hasMonthly: true,
        hasLifetime: false,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.monthlyId]);
      expect(r.selected, Iap.monthlyId,
          reason: 'gelmeyen ürün seçili bırakılamaz');
    });

    test('yalnızca ömür boyu gelirse o seçilir', () {
      final r = resolvePaywallPlans(
        hasYearly: false,
        hasMonthly: false,
        hasLifetime: true,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.lifetimeId]);
      expect(r.selected, Iap.lifetimeId);
    });

    test('geçerli bir seçim varsa DEĞİŞTİRİLMEZ', () {
      // Kullanıcı aylığı seçtiyse, yıllık da mevcut diye seçimi ondan
      // almamalıyız.
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        hasLifetime: false,
        currentSelection: Iap.monthlyId,
      );
      expect(r.selected, Iap.monthlyId);
    });

    test('hiçbir ürün gelmezse liste boş — çağıran hata durumuna düşer', () {
      final r = resolvePaywallPlans(
        hasYearly: false,
        hasMonthly: false,
        hasLifetime: false,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, isEmpty);
      // Boş listede first çağrılmamalı; seçim olduğu gibi korunur.
      expect(r.selected, Iap.yearlyId);
    });

    test('plan sırası korunur: yıllık, aylık, ömür boyu', () {
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        hasLifetime: true,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.yearlyId, Iap.monthlyId, Iap.lifetimeId]);
    });
  });
}
