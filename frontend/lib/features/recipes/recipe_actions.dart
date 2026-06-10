import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/chapters/chapter_list_screen.dart';
import 'package:recetarios/features/recipes/recipe_list_section.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// "Añadir receta": asks for the title, creates an empty recipe in the
/// chapter, and opens it so the user can fill it in via edit mode (FR-020).
Future<void> createRecipeFlow(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  required String chapterId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.addRecipe),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l10n.title),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.accept),
        ),
      ],
    ),
  );
  if (title == null || title.trim().isEmpty) return;

  final recipe = await ref.read(recipesRepositoryProvider).create(chapterId, {
    'title': title.trim(),
    'introduction': <Object>[],
    'ingredients': {
      'servings': null,
      'groups': [
        {'title': null, 'items': <String>[]}
      ],
    },
    'preparation': <Object>[],
    'note': null,
  });
  ref.invalidate(recipeListProvider(chapterId));
  ref.invalidate(chapterListProvider);
  if (context.mounted) {
    context.push('/books/$bookId/chapters/$chapterId/recipes/${recipe.id}');
  }
}

/// Spanish confirmation before deleting a recipe (FR-020).
Future<void> confirmAndDeleteRecipe(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteRecipe),
      content: Text(l10n.deleteRecipeConfirm(recipe.title)),
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
    await ref.read(recipesRepositoryProvider).delete(recipe.id);
    ref.invalidate(recipeListProvider);
    if (context.mounted && context.canPop()) context.pop();
  }
}
