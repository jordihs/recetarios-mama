import 'package:flutter/material.dart';

import 'package:recetarios/data/models.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// List editor for ingredients (FR-019): groups with optional headings,
/// add/remove/reorder items, and a servings field (FR-016).
class IngredientsEditor extends StatefulWidget {
  const IngredientsEditor({super.key, required this.value, required this.onChanged});

  final IngredientsList value;
  final VoidCallback onChanged;

  @override
  State<IngredientsEditor> createState() => _IngredientsEditorState();
}

class _IngredientsEditorState extends State<IngredientsEditor> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: TextFormField(
            initialValue: value.servings ?? '',
            decoration: InputDecoration(labelText: l10n.servingsLabel, isDense: true),
            onChanged: (text) {
              value.servings = text.trim().isEmpty ? null : text.trim();
              widget.onChanged();
            },
          ),
        ),
        for (var g = 0; g < value.groups.length; g++)
          _GroupEditor(
            key: ObjectKey(value.groups[g]),
            group: value.groups[g],
            canDelete: value.groups.length > 1,
            onChanged: widget.onChanged,
            onDelete: () {
              setState(() => value.groups.removeAt(g));
              widget.onChanged();
            },
          ),
        const SizedBox(height: 8),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(l10n.addGroup),
          onPressed: () {
            setState(() => value.groups.add(IngredientGroup()));
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
    super.key,
    required this.group,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final IngredientGroup group;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = widget.group;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: group.title ?? '',
                    decoration: InputDecoration(labelText: l10n.groupTitle, isDense: true),
                    onChanged: (text) {
                      group.title = text.trim().isEmpty ? null : text.trim();
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.canDelete)
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
            for (var i = 0; i < group.items.length; i++)
              Row(
                key: ValueKey('item-$i-${group.items.length}'),
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: group.items[i],
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (text) {
                        group.items[i] = text;
                        widget.onChanged();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.moveUp,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    onPressed: i == 0
                        ? null
                        : () {
                            setState(() {
                              final item = group.items.removeAt(i);
                              group.items.insert(i - 1, item);
                            });
                            widget.onChanged();
                          },
                  ),
                  IconButton(
                    tooltip: l10n.moveDown,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    onPressed: i == group.items.length - 1
                        ? null
                        : () {
                            setState(() {
                              final item = group.items.removeAt(i);
                              group.items.insert(i + 1, item);
                            });
                            widget.onChanged();
                          },
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() => group.items.removeAt(i));
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addIngredient),
                onPressed: () {
                  setState(() => group.items.add(''));
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
