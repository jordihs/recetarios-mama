import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// Spanish cascade-confirmation before deleting a book (FR cascade assumption).
Future<void> confirmAndDeleteBook(BuildContext context, WidgetRef ref, ItemSummary book) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteBook),
      content: Text(l10n.deleteBookConfirm(book.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(booksRepositoryProvider).delete(book.id);
    ref.invalidate(bookListProvider);
  }
}
