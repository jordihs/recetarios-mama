import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// Book → PDF export (FR-029/030/034): starts the backend job, shows progress,
/// and opens the resulting document via the operating system.
Future<void> exportBookPdfFlow(BuildContext context, WidgetRef ref, String bookId) async {
  final l10n = AppLocalizations.of(context)!;
  final api = ref.read(apiClientProvider);

  try {
    final start =
        (await api.post('/pdf/book/$bookId', body: const <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    final jobId = start['job_id'] as String;
    if (!context.mounted) return;

    final path = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PdfProgressDialog(api: api, jobId: jobId),
    );
    if (path == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.pdfSavedAt(path))));
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

class _PdfProgressDialog extends StatefulWidget {
  const _PdfProgressDialog({required this.api, required this.jobId});

  final ApiClient api;
  final String jobId;

  @override
  State<_PdfProgressDialog> createState() => _PdfProgressDialogState();
}

class _PdfProgressDialogState extends State<_PdfProgressDialog> {
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final job = (await widget.api.get('/pdf/jobs/${widget.jobId}') as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      switch (job['status']) {
        case 'done':
          _timer?.cancel();
          Navigator.of(context).pop(job['path'] as String);
        case 'error':
          _timer?.cancel();
          setState(() => _error = job['error'] as String? ?? 'error');
      }
    } on ApiException catch (e) {
      _timer?.cancel();
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Row(
        children: [
          if (_error == null) const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(_error ?? l10n.generatingPdf)),
        ],
      ),
      actions: _error == null
          ? null
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.accept),
              ),
            ],
    );
  }
}
