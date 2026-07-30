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
//
// NOT: Ömür boyu ürünü üründen tamamen kaldırıldı; paywall artık yalnızca
// yıllık ve aylık aboneliği satıyor.

import 'package:flutter_test/flutter_test.dart';

import 'package:rutin/iap.dart';
import 'package:rutin/ui/paywall_screen.dart';

void main() {
  group('resolvePaywallPlans — eksik ürün tüm ekranı kilitlemez', () {
    test('iki plan da gelirse ikisi de gösterilir', () {
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.yearlyId, Iap.monthlyId]);
      expect(r.selected, Iap.yearlyId);
    });

    test('AYLIK gelmezse yıllık satılabilir kalır — 2.1(b) reddinin senaryosu',
        () {
      // Üretimdeki durum birebir: aylık kimlik servis edilemiyor.
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: false,
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
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, [Iap.monthlyId]);
      expect(r.selected, Iap.monthlyId,
          reason: 'gelmeyen ürün seçili bırakılamaz');
    });

    test('geçerli bir seçim varsa DEĞİŞTİRİLMEZ', () {
      // Kullanıcı aylığı seçtiyse, yıllık da mevcut diye seçimi ondan
      // almamalıyız.
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        currentSelection: Iap.monthlyId,
      );
      expect(r.selected, Iap.monthlyId);
    });

    test('hiçbir ürün gelmezse liste boş — çağıran hata durumuna düşer', () {
      final r = resolvePaywallPlans(
        hasYearly: false,
        hasMonthly: false,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans, isEmpty);
      // Boş listede first çağrılmamalı; seçim olduğu gibi korunur.
      expect(r.selected, Iap.yearlyId);
    });

    test('plan sırası korunur: önce yıllık, sonra aylık', () {
      // Sıra bilinçli: yıllık plan varsayılan ve en yüksek LTV'li olan.
      final r = resolvePaywallPlans(
        hasYearly: true,
        hasMonthly: true,
        currentSelection: Iap.yearlyId,
      );
      expect(r.plans.first, Iap.yearlyId);
    });
  });

  group('Ömür boyu ürünü satıştan kaldırıldı ama geri yükleme korunuyor', () {
    // Play Console'da bu ürün tanımlıydı ve satın alma testi yapıldı. Daha
    // önce satın almış biri "Geri Yükle" dediğinde makbuz DOĞRU uç noktadan
    // doğrulanmalı; aksi halde ödediği Pro'yu kaybeder.
    test('eski ömür boyu kimliği hâlâ "lifetime" olarak doğrulanır', () {
      expect(Iap.kindOf(Iap.legacyLifetimeId), 'lifetime');
      expect(Iap.legacyLifetimeId, 'rutin_pro_lifetime');
    });

    test('abonelikler etkilenmedi', () {
      expect(Iap.kindOf(Iap.yearlyId), 'subscription');
      expect(Iap.kindOf(Iap.monthlyId), 'subscription');
    });
  });
}
