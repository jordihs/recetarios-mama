import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/local/legacy_importer.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';

const _jsonTypeGroup = XTypeGroup(label: 'Recetario JSON', extensions: ['json']);

Future<void> importLegacyFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final importer = ref.read(legacyImporterProvider);

  final file = await openFile(acceptedTypeGroups: const [_jsonTypeGroup]);
  if (file == null || !context.mounted) return;

  try {
    final inspection = await importer.inspect(file.path);
    if (!context.mounted) return;

    var onCollision = 'keep_both';
    if (inspection['collision'] == true) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importLegacyCollisionTitle),
          content: Text(
              l10n.importLegacyCollisionBody(inspection['book_title'] as String? ?? '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('keep_both'),
              child: Text(l10n.keepBoth),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('replace'),
              child: Text(l10n.replaceExisting),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      onCollision = choice;
    }

    final report = await importer.run(file.path, onCollision);
    ref.invalidate(bookListProvider);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importReportTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.importReportBody(
                report.chapters,
                report.recipes,
                report.imagesImported,
              )),
              if (report.imagesMissing.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.importReportMissingImages,
                    style: Theme.of(context).textTheme.titleSmall),
                for (final path in report.imagesMissing) Text('• $path'),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  } on LegacyImportException catch (e) {
    if (!context.mounted) return;
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
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
