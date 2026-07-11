import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _yearly = true;

  List<(String, String, String)> get _features => T.en
      ? const [
          ('🚫', 'Ad-free experience', 'All ads completely removed'),
          ('🎨', 'All premium themes', 'Personalize with 6 exclusive themes'),
          ('🔥', 'Unlimited streak counters', '2 in free, unlimited in Pro'),
          ('📊', 'Detailed statistics', 'Long-term charts and insights'),
          ('📱', 'Home screen widget', 'Your streak always in sight (soon)'),
          ('☁️', 'Cloud backup', 'Your data safe across devices (soon)'),
        ]
      : const [
          ('🚫', 'Reklamsız deneyim', 'Tüm reklamlar tamamen kalkar'),
          ('🎨', 'Tüm premium temalar', '6 özel tema ile uygulamanı kişiselleştir'),
          ('🔥', 'Sınırsız streak sayacı', "Ücretsizde 2, Pro'da dilediğin kadar"),
          ('📊', 'Detaylı istatistikler', 'Uzun dönem grafikler ve içgörüler'),
          ('📱', "Ana ekran widget'ı", "Streak'in her an gözünün önünde (yakında)"),
          ('☁️', 'Bulut yedekleme', 'Verilerin güvende, cihaz değişse bile (yakında)'),
        ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.accent, c.amber]),
                shape: BoxShape.circle,
              ),
              child: const Text('🔥', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('Rutin Pro',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(t('Alışkanlıklarına tam güç', 'Full power for your habits'),
                style: TextStyle(fontSize: 14, color: c.muted)),
          ),
          const SizedBox(height: 20),
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(f.$3,
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: c.green, size: 20),
                  ],
                ),
              )),
          const SizedBox(height: 12),

          // Plan seçimi — yıllık öne çıkar
          _planCard(
            c,
            selected: _yearly,
            title: t('Yıllık', 'Yearly'),
            price: t('₺399,99 / yıl', '₺399.99 / year'),
            sub: t('Ayda sadece ₺33 — %58 tasarruf', 'Just ₺33/month — save 58%'),
            badge: t('EN POPÜLER', 'MOST POPULAR'),
            onTap: () => setState(() => _yearly = true),
          ),
          const SizedBox(height: 8),
          _planCard(
            c,
            selected: !_yearly,
            title: t('Aylık', 'Monthly'),
            price: t('₺79,99 / ay', '₺79.99 / month'),
            sub: t('İstediğin zaman iptal et', 'Cancel anytime'),
            onTap: () => setState(() => _yearly = false),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              // TODO: Google Play Billing / RevenueCat entegrasyonu.
              toast(context,
                  t('Ödeme sistemi mağaza hesabı açıldığında bağlanacak 🙂', 'Payments will be enabled once the store account is live 🙂'));
            },
            child: Text(t('7 gün ücretsiz dene', 'Try 7 days free')),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _yearly
                  ? t('Deneme bitince ₺399,99/yıl. İstediğin an iptal.', 'Then ₺399.99/year. Cancel anytime.')
                  : t('Deneme bitince ₺79,99/ay. İstediğin an iptal.', 'Then ₺79.99/month. Cancel anytime.'),
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ),
          const SizedBox(height: 16),
          if (!s.isPro)
            Center(
              child: TextButton(
                onPressed: () {
                  s.activatePro();
                  toast(context, t('✅ Test modu: Pro açıldı', '✅ Test mode: Pro unlocked'));
                  Navigator.pop(context);
                },
                child: Text(t("Geliştirici test modu: Pro'yu aç", 'Developer test mode: unlock Pro'),
                    style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planCard(RutinColors c,
      {required bool selected,
      required String title,
      required String price,
      required String sub,
      String? badge,
      required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.accent : c.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? c.accent : c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(badge,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  Text(sub, style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: c.accent2)),
          ],
        ),
      ),
    );
  }
}
