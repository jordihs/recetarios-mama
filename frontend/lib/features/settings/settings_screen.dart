import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/l10n/app_localizations.dart';

final settingsProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(settingsStoreProvider).getAll(),
);

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
              subtitle: Text(values['pdf_output_dir'] ?? ''),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  final dir = await getDirectoryPath();
                  if (dir == null) return;
                  await ref.read(settingsStoreProvider).update({'pdf_output_dir': dir});
                  ref.invalidate(settingsProvider);
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
