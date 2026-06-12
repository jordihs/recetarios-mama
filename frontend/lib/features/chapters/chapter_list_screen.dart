import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/chapters_repository.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';
import 'package:recetarios/widgets/markdown_view.dart';

final chaptersRepositoryProvider =
    Provider<ChaptersRepository>((ref) => ChaptersRepository(ref.watch(apiClientProvider)));

/// Sibling chapters of (bookId, parentChapterId?).
final chapterListProvider =
    FutureProvider.family<List<ItemSummary>, ({String bookId, String? parentId})>(
  (ref, args) =>
      ref.watch(chaptersRepositoryProvider).list(args.bookId, parentChapterId: args.parentId),
);

final chapterDetailProvider = FutureProvider.family<ChapterDetail, String>(
  (ref, id) => ref.watch(chaptersRepositoryProvider).get(id),
);

/// Chapter browser: top level of a book (chapterId == null) or a chapter's
/// subchapters + recipes (chapterId != null).
///
/// The parent item's full presentation content (book or chapter introduction)
/// is rendered above the listings, with an edit action in the AppBar — the
/// recipe view is the only place that does not show its parent's description.
class ChapterListScreen extends ConsumerWidget {
  const ChapterListScreen({super.key, required this.bookId, this.chapterId, this.recipesSection});

  final String bookId;
  final String? chapterId;

  /// Injected by the recipes feature: builds the recipe section for a chapter.
  final Widget? recipesSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chapters = ref.watch(chapterListProvider((bookId: bookId, parentId: chapterId)));

    final String parentTitle;
    final String parentPresentation;
    final String? parentNote;
    final String editRoute;
    final String editTooltip;
    if (chapterId == null) {
      final book = ref.watch(bookDetailProvider(bookId));
      parentTitle = book.value?.title ?? '';
      parentPresentation = book.value?.presentation ?? '';
      parentNote = book.value?.note;
      editRoute = '/books/$bookId/edit';
      editTooltip = l10n.editBook;
    } else {
      final chapter = ref.watch(chapterDetailProvider(chapterId!));
      parentTitle = chapter.value?.title ?? '';
      parentPresentation = chapter.value?.presentation ?? '';
      parentNote = chapter.value?.note;
      editRoute = '/books/$bookId/chapters/$chapterId/edit';
      editTooltip = l10n.editChapter;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(parentTitle),
        actions: [
          IconButton(
            tooltip: editTooltip,
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(editRoute),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final query = chapterId == null ? '' : '?parent=$chapterId';
          context.push('/books/$bookId/chapters/new$query');
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addChapter),
      ),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          final api = ref.watch(apiClientProvider);
          return CustomScrollView(
            slivers: [
              // Full introduction of the parent book/chapter (FR-006 companion:
              // lists show the truncated description; this is the full content).
              if (parentPresentation.isNotEmpty || (parentNote?.isNotEmpty ?? false))
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (parentPresentation.isNotEmpty)
                              MarkdownView(markdown: parentPresentation, api: api),
                            // The note sits at the foot of the content, in the
                            // recipe-note visual style (FR-004 companion).
                            if (parentNote != null && parentNote.isNotEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.note,
                                          style: Theme.of(context).textTheme.titleSmall),
                                      const SizedBox(height: 4),
                                      Text(parentNote),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (items.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      chapterId == null ? l10n.chapters : l10n.subchapters,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ChapterGrid(
                      items: items, bookId: bookId, parentId: chapterId, api: api),
                ),
              ] else if (recipesSection == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text(l10n.noChapters, textAlign: TextAlign.center)),
                  ),
                ),
              if (recipesSection != null) SliverToBoxAdapter(child: recipesSection),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterGrid extends ConsumerWidget {
  const _ChapterGrid({required this.items, required this.bookId, this.parentId, required this.api});

  final List<ItemSummary> items;
  final String bookId;
  final String? parentId;
  final dynamic api;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 280).floor().clamp(1, 6);
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: [
          for (var i = 0; i < items.length; i++)
            ItemCard(
              title: items[i].title,
              description: items[i].description,
              imageUrl: items[i].image == null ? null : api.imageUrl(items[i].image!),
              onTap: () => context.push('/books/$bookId/chapters/${items[i].id}'),
              trailing: _ChapterMenu(
                  item: items[i], index: i, items: items, bookId: bookId, parentId: parentId),
            ),
        ],
      );
    });
  }
}

class _ChapterMenu extends ConsumerWidget {
  const _ChapterMenu({
    required this.item,
    required this.index,
    required this.items,
    required this.bookId,
    this.parentId,
  });

  final ItemSummary item;
  final int index;
  final List<ItemSummary> items;
  final String bookId;
  final String? parentId;

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
          onPressed: () => context.push('/books/$bookId/chapters/${item.id}/edit'),
          child: Text(l10n.editChapter),
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
          leadingIcon: const Icon(Icons.delete),
          onPressed: () => _confirmDelete(context, ref),
          child: Text(l10n.deleteChapter),
        ),
      ],
    );
  }

  Future<void> _move(WidgetRef ref, int delta) async {
    final ids = items.map((e) => e.id).toList();
    final target = index + delta;
    ids[index] = ids[target];
    ids[target] = item.id;
    await ref.read(chaptersRepositoryProvider).reorder(bookId, parentId, ids);
    ref.invalidate(chapterListProvider((bookId: bookId, parentId: parentId)));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteChapter),
        content: Text(l10n.deleteChapterConfirm(item.title)),
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
      await ref.read(chaptersRepositoryProvider).delete(item.id);
      ref.invalidate(chapterListProvider((bookId: bookId, parentId: parentId)));
    }
  }
}
