import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/recipes/print_dialog.dart';
import 'package:recetarios/features/recipes/recipe_actions.dart';
import 'package:recetarios/features/recipes/recipe_edit_form.dart';
import 'package:recetarios/features/recipes/recipe_list_section.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/block_renderer.dart';

final recipeDetailProvider = FutureProvider.family<Recipe, String>(
  (ref, id) => ref.watch(recipesRepositoryProvider).get(id),
);

/// Recipe screen: opens read-only (FR-014), toggles into edit mode (FR-017)
/// with save / discard-changes buttons (FR-018) and an unsaved-changes
/// navigation guard (FR-021).
class RecipeViewScreen extends ConsumerStatefulWidget {
  const RecipeViewScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeViewScreen> createState() => _RecipeViewScreenState();
}

class _RecipeViewScreenState extends ConsumerState<RecipeViewScreen> {
  bool _editing = false;
  bool _dirty = false;
  Recipe? _draft;

  Recipe _cloneOf(Recipe recipe) {
    final json = (jsonDecode(jsonEncode(recipe.toJson())) as Map).cast<String, dynamic>();
    json['id'] = recipe.id;
    return Recipe.fromJson(json);
  }

  void _startEditing(Recipe recipe) {
    setState(() {
      _draft = _cloneOf(recipe);
      _dirty = false;
      _editing = true;
    });
  }

  Future<void> _save() async {
    final draft = _draft!;
    await ref.read(recipesRepositoryProvider).update(draft.id, draft.toJson());
    ref.invalidate(recipeDetailProvider(widget.recipeId));
    setState(() {
      _editing = false;
      _draft = null;
      _dirty = false;
    });
  }

  void _discard() {
    setState(() {
      _editing = false;
      _draft = null;
      _dirty = false;
    });
  }

  Future<bool> _confirmLoseChanges() async {
    if (!_editing || !_dirty) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recipe = ref.watch(recipeDetailProvider(widget.recipeId));

    return PopScope(
      canPop: !(_editing && _dirty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLoseChanges() && context.mounted) {
          _discard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? (_draft?.title ?? '') : (recipe.value?.title ?? '')),
          actions: [
            if (!_editing && recipe.hasValue) ...[
              IconButton(
                tooltip: l10n.print,
                icon: const Icon(Icons.print),
                onPressed: () => printRecipeFlow(context, ref, widget.recipeId),
              ),
              IconButton(
                tooltip: l10n.edit,
                icon: const Icon(Icons.edit),
                onPressed: () => _startEditing(recipe.value!),
              ),
              IconButton(
                tooltip: l10n.deleteRecipe,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmAndDeleteRecipe(context, ref, recipe.value!),
              ),
            ],
          ],
        ),
        body: recipe.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (data) {
            if (!_editing) return RecipeContentView(recipe: data);
            return Column(
              children: [
                Expanded(
                  child: RecipeEditForm(
                    draft: _draft!,
                    onChanged: () {
                      if (!_dirty) setState(() => _dirty = true);
                    },
                  ),
                ),
                Material(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _discard,
                          child: Text(l10n.discardChanges),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(onPressed: _save, child: Text(l10n.save)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The read-only recipe body: introduction → ingredients → preparation → note.
class RecipeContentView extends ConsumerWidget {
  const RecipeContentView({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe.image != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(api.imageUrl(recipe.image!),
                          height: 260, fit: BoxFit.cover),
                    ),
                  ),
                if (recipe.introduction.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  BlockRenderer(blocks: recipe.introduction, api: api),
                ],
                const SizedBox(height: 16),
                Text(l10n.ingredients, style: theme.textTheme.titleLarge),
                if (recipe.ingredients.servings != null &&
                    recipe.ingredients.servings!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.servings(recipe.ingredients.servings!),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                for (final group in recipe.ingredients.groups) ...[
                  if (group.title != null && group.title!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(group.title!, style: theme.textTheme.titleSmall),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in group.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(item)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(l10n.preparation, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                BlockRenderer(blocks: recipe.preparation, api: api),
                if (recipe.note != null && recipe.note!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.note, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(recipe.note!),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
