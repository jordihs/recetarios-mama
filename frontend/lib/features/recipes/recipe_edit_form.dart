import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_form_screen.dart' show imagesTypeGroup;
import 'package:recetarios/features/recipes/ingredients_editor.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/block_editor/block_list_editor.dart';

/// Edit-mode form (FR-017/019): every element of the recipe is editable with
/// section-appropriate editors. Mutates [draft] in place; [onChanged] marks
/// the draft dirty.
class RecipeEditForm extends ConsumerWidget {
  const RecipeEditForm({super.key, required this.draft, required this.onChanged});

  final Recipe draft;
  final VoidCallback onChanged;

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
                TextFormField(
                  initialValue: draft.title,
                  decoration: InputDecoration(labelText: l10n.title),
                  maxLength: 200,
                  onChanged: (value) {
                    draft.title = value;
                    onChanged();
                  },
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image),
                      label: Text(draft.image == null ? l10n.chooseImage : l10n.coverImage),
                      onPressed: () async {
                        final file =
                            await openFile(acceptedTypeGroups: const [imagesTypeGroup]);
                        if (file == null) return;
                        final bytes = await file.readAsBytes();
                        final result = await api.uploadImage(bytes, file.name);
                        draft.image = result['hash'] as String;
                        onChanged();
                      },
                    ),
                    if (draft.image != null)
                      TextButton(
                        onPressed: () {
                          draft.image = null;
                          onChanged();
                        },
                        child: Text(l10n.removeImage),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(l10n.introduction, style: theme.textTheme.titleLarge),
                BlockListEditor(blocks: draft.introduction, api: api, onChanged: onChanged),
                const SizedBox(height: 16),
                Text(l10n.ingredients, style: theme.textTheme.titleLarge),
                IngredientsEditor(value: draft.ingredients, onChanged: onChanged),
                const SizedBox(height: 16),
                Text(l10n.preparation, style: theme.textTheme.titleLarge),
                BlockListEditor(blocks: draft.preparation, api: api, onChanged: onChanged),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: draft.note ?? '',
                  decoration: InputDecoration(labelText: l10n.note),
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) {
                    draft.note = value.trim().isEmpty ? null : value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
