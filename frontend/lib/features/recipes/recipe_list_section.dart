import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/data/recipes_repository.dart';
import 'package:recetarios/features/recipes/recipe_actions.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>(
  (ref) => RecipesRepository(ref.watch(repositoryProvider)),
);

final recipeListProvider = FutureProvider.family<List<ItemSummary>, String>(
  (ref, chapterId) => ref.watch(recipesRepositoryProvider).list(chapterId),
);

final titlesOnlyProvider = StateProvider.family<bool, String>((ref, chapterId) => false);

class RecipeListSection extends ConsumerWidget {
  const RecipeListSection({super.key, required this.bookId, required this.chapterId});

  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recipes = ref.watch(recipeListProvider(chapterId));
    final titlesOnly = ref.watch(titlesOnlyProvider(chapterId));

    return recipes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('$error')),
      ),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(l10n.recipes, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 12),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addRecipe),
                  onPressed: () =>
                      createRecipeFlow(context, ref, bookId: bookId, chapterId: chapterId),
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  Tooltip(
                    message: titlesOnly ? l10n.detailedView : l10n.titlesOnly,
                    child: Semantics(
                      label: titlesOnly ? l10n.detailedView : l10n.titlesOnly,
                      child: Switch(
                        value: titlesOnly,
                        onChanged: (value) =>
                            ref.read(titlesOnlyProvider(chapterId).notifier).state = value,
                      ),
                    ),
                  ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(l10n.titlesOnly),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.noRecipes)),
            )
          else if (titlesOnly)
            _TitleRows(items: items, bookId: bookId, chapterId: chapterId)
          else
            _RecipeGrid(items: items, bookId: bookId, chapterId: chapterId),
        ],
      ),
    );
  }
}

class _TitleRows extends ConsumerWidget {
  const _TitleRows({required this.items, required this.bookId, required this.chapterId});

  final List<ItemSummary> items;
  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) => ItemCard(
        compact: true,
        title: items[i].title,
        onTap: () =>
            context.push('/books/$bookId/chapters/$chapterId/recipes/${items[i].id}'),
      ),
    );
  }
}

class _RecipeGrid extends ConsumerWidget {
  const _RecipeGrid({required this.items, required this.bookId, required this.chapterId});

  final List<ItemSummary> items;
  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageStore = ref.watch(imageStoreProvider);
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
              imageFilePath: items[i].image == null
                  ? null
                  : imageStore.pathFor(items[i].image!),
              onTap: () =>
                  context.push('/books/$bookId/chapters/$chapterId/recipes/${items[i].id}'),
              trailing: _RecipeMenu(item: items[i], index: i, items: items, chapterId: chapterId),
            ),
        ],
      );
    });
  }
}

class _RecipeMenu extends ConsumerWidget {
  const _RecipeMenu({
    required this.item,
    required this.index,
    required this.items,
    required this.chapterId,
  });

  final ItemSummary item;
  final int index;
  final List<ItemSummary> items;
  final String chapterId;

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
          leadingIcon: const Icon(Icons.arrow_upward),
          onPressed: index == 0 ? null : () => _move(ref, -1),
          child: Text(l10n.moveUp),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_downward),
          onPressed: index == items.length - 1 ? null : () => _move(ref, 1),
          child: Text(l10n.moveDown),
        ),
      ],
    );
  }

  Future<void> _move(WidgetRef ref, int delta) async {
    final ids = items.map((e) => e.id).toList();
    final target = index + delta;
    ids[index] = ids[target];
    ids[target] = item.id;
    await ref.read(recipesRepositoryProvider).reorder(chapterId, ids);
    ref.invalidate(recipeListProvider(chapterId));
  }
}
