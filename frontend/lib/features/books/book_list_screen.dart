import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/books_repository.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_actions.dart';
import 'package:recetarios/features/books/export_book_pdf.dart';
import 'package:recetarios/features/transfer/legacy_import_flow.dart';
import 'package:recetarios/features/transfer/library_transfer_flow.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';

final booksRepositoryProvider =
    Provider<BooksRepository>((ref) => BooksRepository(ref.watch(apiClientProvider)));

final bookListProvider =
    FutureProvider<List<ItemSummary>>((ref) => ref.watch(booksRepositoryProvider).list());

class BookListScreen extends ConsumerWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final books = ref.watch(bookListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          MenuAnchor(
            builder: (context, controller, _) => IconButton(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              icon: const Icon(Icons.more_vert),
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.upload_file),
                onPressed: () => importLegacyFlow(context, ref),
                child: Text(l10n.importLegacy),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.archive),
                onPressed: () => exportLibraryFlow(context, ref),
                child: Text(l10n.exportLibrary),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.unarchive),
                onPressed: () => importLibraryFlow(context, ref),
                child: Text(l10n.importLibrary),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
                child: Text(l10n.settings),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/books/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addBook),
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorRetry(
          message: '$error',
          onRetry: () => ref.invalidate(bookListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noBooks, textAlign: TextAlign.center),
              ),
            );
          }
          final api = ref.watch(apiClientProvider);
          return ResponsiveCardGrid(
            children: [
              for (var i = 0; i < items.length; i++)
                ItemCard(
                  title: items[i].title,
                  description: items[i].description,
                  imageUrl: items[i].image == null ? null : api.imageUrl(items[i].image!),
                  onTap: () => context.push('/books/${items[i].id}'),
                  trailing: _BookMenu(item: items[i], index: i, items: items),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BookMenu extends ConsumerWidget {
  const _BookMenu({required this.item, required this.index, required this.items});

  final ItemSummary item;
  final int index;
  final List<ItemSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return MenuAnchor(
      builder: (context, controller, _) => IconButton(
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_vert),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit),
          onPressed: () => context.push('/books/${item.id}/edit'),
          child: Text(l10n.editBook),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_upward),
          onPressed: index == 0 ? null : () => _move(ref, -1),
          child: Text(l10n.moveUp),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_downward),
          onPressed: index == items.length - 1 ? null : () => _move(ref, 1),
          child: Text(l10n.moveDown),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf),
          onPressed: () => exportBookPdfFlow(context, ref, item.id),
          child: Text(l10n.exportBookPdf),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete),
          onPressed: () => confirmAndDeleteBook(context, ref, item),
          child: Text(l10n.deleteBook),
        ),
      ],
    );
  }

  Future<void> _move(WidgetRef ref, int delta) async {
    final ids = items.map((e) => e.id).toList();
    final target = index + delta;
    ids[index] = ids[target];
    ids[target] = item.id;
    await ref.read(booksRepositoryProvider).reorder(ids);
    ref.invalidate(bookListProvider);
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
