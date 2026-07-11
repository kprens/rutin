/// Ortak küçük widget'lar.
library;

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: c.muted,
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String text;
  const EmptyCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, height: 1.6),
        ),
      ),
    );
  }
}

/// Saatli satır: takvim/program kayıtları için.
class EventRow extends StatelessWidget {
  final String time;
  final String name;
  final String? tag;
  final VoidCallback? onDelete;

  const EventRow({
    super.key,
    required this.time,
    required this.name,
    this.tag,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = RutinColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                time.isEmpty ? '—' : time,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: c.accent2, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.card2,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(tag!, style: TextStyle(fontSize: 11, color: c.muted)),
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: c.muted),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context,
    {required String title, required String text, required String confirmLabel}) async {
  final c = RutinColors.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: c.card,
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(text, style: TextStyle(color: c.muted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx, false),
          child: Text(t('Vazgeç', 'Cancel'), style: TextStyle(color: c.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dCtx, true),
          child: Text(confirmLabel, style: TextStyle(color: c.red)),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
}

/// Geri alınabilir silme bildirimi.
void toastUndo(BuildContext context, String msg, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: t('Geri al', 'Undo'), onPressed: onUndo),
    ));
}
