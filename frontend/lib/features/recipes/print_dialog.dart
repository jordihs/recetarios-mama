import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// Print button flow (FR-031..034): choose include/skip introduction and
/// images (or cancel), generate the PDF into the configured folder, and ask
/// the OS to open it.
Future<void> printRecipeFlow(BuildContext context, WidgetRef ref, String recipeId) async {
  final l10n = AppLocalizations.of(context)!;
  final choices = await showDialog<({bool intro, bool images})>(
    context: context,
    builder: (context) => const _PrintChoicesDialog(),
  );
  if (choices == null || !context.mounted) return; // cancelled → no PDF (FR-031)

  final api = ref.read(apiClientProvider);
  try {
    final result = (await api.post('/pdf/recipe/$recipeId', body: {
      'include_introduction': choices.intro,
      'include_images': choices.images,
    }) as Map)
        .cast<String, dynamic>();
    final path = result['path'] as String;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pdfSavedAt(path))));
    }
    await OpenFilex.open(path);
  } on ApiException catch (e) {
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
  }
}

class _PrintChoicesDialog extends StatefulWidget {
  const _PrintChoicesDialog();

  @override
  State<_PrintChoicesDialog> createState() => _PrintChoicesDialogState();
}

class _PrintChoicesDialogState extends State<_PrintChoicesDialog> {
  bool _intro = true;
  bool _images = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.printRecipeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: _intro,
            title: Text(l10n.includeIntroduction),
            onChanged: (value) => setState(() => _intro = value ?? true),
          ),
          CheckboxListTile(
            value: _images,
            title: Text(l10n.includeImages),
            onChanged: (value) => setState(() => _images = value ?? true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((intro: _intro, images: _images)),
          child: Text(l10n.print),
        ),
      ],
    );
  }
}
