import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/l10n/app_localizations.dart';

final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/settings');
  return (data as Map).cast<String, dynamic>();
});

/// Configuration menu (FR-035): persistent default PDF destination folder.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (values) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(l10n.pdfOutputDir),
              subtitle: Text(values['pdf_output_dir'] as String? ?? ''),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  final dir = await getDirectoryPath();
                  if (dir == null) return;
                  try {
                    await ref
                        .read(apiClientProvider)
                        .put('/settings', body: {'pdf_output_dir': dir});
                    ref.invalidate(settingsProvider);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                },
                child: Text(l10n.chooseFolder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
