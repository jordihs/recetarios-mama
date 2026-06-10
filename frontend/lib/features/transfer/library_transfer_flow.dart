import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';

const _archiveTypeGroup =
    XTypeGroup(label: 'Biblioteca de recetarios', extensions: ['recetarios']);

/// Export the whole library into a single archive file (FR-027).
Future<void> exportLibraryFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final location = await getSaveLocation(
    suggestedName: 'biblioteca.recetarios',
    acceptedTypeGroups: const [_archiveTypeGroup],
  );
  if (location == null || !context.mounted) return;

  try {
    await ref.read(apiClientProvider).post('/library/export', body: {'path': location.path});
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.exportLibraryDone(location.path))));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Import a library archive, replacing everything after explicit
/// confirmation (FR-028).
Future<void> importLibraryFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final file = await openFile(acceptedTypeGroups: const [_archiveTypeGroup]);
  if (file == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importLibraryConfirmTitle),
      content: Text(l10n.importLibraryConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.accept),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref
        .read(apiClientProvider)
        .post('/library/import', body: {'path': file.path, 'confirm_replace': true});
    ref.invalidate(bookListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importLibraryDone)));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.errorTitle),
          content: Text(e.message),
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
}
