import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import 'rutin_ui.dart';

/// Kilometre taşı kutlaması — yeni koyu arayüzle uyumlu tam ekran.
class UiCelebrationScreen extends StatelessWidget {
  final Streak streak;
  final int milestone;
  const UiCelebrationScreen(
      {super.key, required this.streak, required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1E3F), RC.bg],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(Icons.celebration_rounded, size: 88, color: RC.purpleBright),
                const SizedBox(height: 24),
                Text('$milestone',
                    style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: RC.purpleBright)),
                Text(t('gün!', 'days!'),
                    style: TextStyle(fontSize: 22, color: RC.muted)),
                const SizedBox(height: 20),
                Text(
                  t('"${streak.name}" için $milestone günlük kilometre taşına ulaştın. Harikasın!',
                      'You reached the $milestone-day milestone for "${streak.name}". Amazing!'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: RC.text, height: 1.5),
                ),
                const Spacer(),
                RButton(t('Devam Et', 'Continue'),
                    onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
