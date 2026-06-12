import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// `GET /library/status` at startup; `current` lets the app through.
final libraryStatusProvider = FutureProvider<String>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/library/status');
  return (data as Map)['format'] as String? ?? 'current';
});

/// Blocks the whole UI when the library predates schema v2 (FR-014): a v1
/// database is never opened; the only way forward is an explicitly confirmed
/// reset (images are preserved on disk for re-import).
class LibraryResetGate extends ConsumerWidget {
  const LibraryResetGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(libraryStatusProvider);
    return status.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Status unreachable ⇒ let the app surface its own connection errors.
      error: (_, _) => child,
      data: (format) => format == 'legacy' ? const _LegacyLibraryScreen() : child,
    );
  }
}

class _LegacyLibraryScreen extends ConsumerStatefulWidget {
  const _LegacyLibraryScreen();

  @override
  ConsumerState<_LegacyLibraryScreen> createState() => _LegacyLibraryScreenState();
}

class _LegacyLibraryScreenState extends ConsumerState<_LegacyLibraryScreen> {
  bool _resetting = false;

  Future<void> _confirmAndReset() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.libraryResetConfirmTitle),
        content: Text(l10n.libraryResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.libraryLegacyResetButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await ref.read(apiClientProvider).post('/library/reset', body: {'confirm': true});
      ref.invalidate(libraryStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.libraryResetDone)),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.libraryLegacyTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(l10n.libraryLegacyBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_resetting)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _confirmAndReset,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.libraryLegacyResetButton),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
