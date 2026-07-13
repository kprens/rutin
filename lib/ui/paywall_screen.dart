import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../iap.dart';
import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'water_screen.dart' show rutinAppBar;

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  List<(String, String, String)> get _features => [
        ('♾️', t('Sınırsız Alışkanlık', 'Unlimited Habits'),
            t('İstediğin kadar alışkanlık ekle', 'Track as many habits as you want')),
        ('📊', t('Gelişmiş İstatistik', 'Advanced Analytics'),
            t('Derin içgörüler ve raporlar', 'Deep insights and custom reports')),
        ('🔔', t('Akıllı Hatırlatma', 'Smart Reminders'),
            t('En doğru zamanda hatırlatma', 'AI-powered reminder timing')),
        ('🏆', t('Tüm Başarımlar', 'All Achievements'),
            t('Tüm rozet koleksiyonu', 'Unlock the full badge collection')),
        ('📤', t('Dışa Aktar & Yedekle', 'Export & Backup'),
            t('İstediğin an tam veri dışa aktarımı', 'Full data export at any time')),
        ('🎨', t('Özel Temalar', 'Custom Themes'),
            t('Deneyimini kişiselleştir', 'Personalize your experience')),
        ('👥', t('Sorumluluk Ortağı', 'Accountability Partner'),
            t('İlerlemeni bir arkadaşınla paylaş', 'Share progress with a buddy')),
        ('🤖', t('AI İçgörüleri', 'AI Insights'),
            t('Kişiselleştirilmiş öneriler', 'Personalized habit recommendations')),
      ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Rutin Pro', 'Rutin Pro')),
              const SizedBox(height: 22),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: RG.purpleBtn,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: RC.purple.withValues(alpha: 0.5),
                              blurRadius: 30),
                        ],
                      ),
                      child: const Text('💎', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                        s.isPro
                            ? t('Pro aktif 🎉', 'Pro is active 🎉')
                            : t('Rutin Pro\'yu Aç', 'Unlock Rutin Pro'),
                        style: RText.h2, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        s.isPro
                            ? t('Tüm özelliklerin kilidi açık.',
                                'All features are unlocked.')
                            : t('Alışkanlıklarını dönüştürmek için gereken her şey',
                                'Everything you need to transform your habits'),
                        style: RText.muted, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              Text(t('Neler var', "What's included"), style: RText.title),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.98,
                children: _features.map(_feature).toList(),
              ),
              const SizedBox(height: 20),

              // ---- Fiyat + CTA (Pro değilse) ----
              if (!s.isPro)
                AnimatedBuilder(
                  animation: Iap.instance,
                  builder: (context, _) {
                    final price =
                        Iap.instance.priceFor(Iap.monthlyId, '\$4.99');
                    final pending = Iap.instance.purchasePending;
                    return Column(
                      children: [
                        RCard(
                          color: RC.tintPurple,
                          border: RC.purple.withValues(alpha: 0.4),
                          child: Column(
                            children: [
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                      text: price,
                                      style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: RC.text)),
                                  TextSpan(
                                      text: t(' / ay', ' / month'),
                                      style: const TextStyle(
                                          color: RC.muted, fontSize: 15)),
                                ]),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                  t('7 gün ücretsiz · istediğin an iptal',
                                      '7-day free trial · cancel anytime'),
                                  style: const TextStyle(
                                      color: RC.muted, fontSize: 13)),
                              const SizedBox(height: 16),
                              pending
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                          color: RC.purpleBright),
                                    )
                                  : RButton(
                                      t('Ücretsiz Denemeyi Başlat',
                                          'Start Free Trial'),
                                      onTap: () => _buy(context)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Iap.instance.restore(),
                          child: Center(
                            child: Text(
                                t('Satın Alımları Geri Yükle',
                                    'Restore Purchases'),
                                style: const TextStyle(
                                    color: RC.muted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _buy(BuildContext context) {
    if (Iap.instance.available &&
        Iap.instance.productFor(Iap.monthlyId) != null) {
      Iap.instance.buy(Iap.monthlyId);
    } else {
      // Mağazaya ulaşılamıyor (öykünücü/masaüstü) — test için Pro'yu aç.
      context.read<AppState>().activatePro();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(t('Pro etkinleştirildi (test).',
                'Pro activated (test mode).'))));
    }
  }

  Widget _feature((String, String, String) f) {
    final (emoji, title, desc) = f;
    return RCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 6),
          Text(desc,
              style:
                  const TextStyle(color: RC.muted, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }
}
