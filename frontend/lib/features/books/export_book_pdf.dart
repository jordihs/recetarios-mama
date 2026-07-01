import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/l10n/app_localizations.dart';

Future<void> exportBookPdfFlow(BuildContext context, WidgetRef ref, String bookId) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final path = await ref.read(pdfServiceProvider).buildBookPdf(bookId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.pdfSavedAt(path))));
    await OpenFilex.open(path);
  } catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.errorTitle),
        content: Text('$e'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  }
}
