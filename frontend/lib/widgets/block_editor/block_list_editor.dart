import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/l10n/app_localizations.dart';

const _imagesTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
);

/// Editable list of content blocks (FR-019): paragraphs and headings as text
/// fields, images with caption/placement, image groups with grid/row layout,
/// and tables. Blocks can be added, moved, and deleted.
///
/// Blocks are mutated in place; [onChanged] signals the parent that the
/// draft differs from the saved state.
class BlockListEditor extends StatefulWidget {
  const BlockListEditor({
    super.key,
    required this.blocks,
    required this.api,
    required this.onChanged,
  });

  final List<ContentBlock> blocks;
  final ApiClient api;
  final VoidCallback onChanged;

  @override
  State<BlockListEditor> createState() => _BlockListEditorState();
}

class _BlockListEditorState extends State<BlockListEditor> {
  void _notify() => widget.onChanged();

  void _add(ContentBlock block) {
    setState(() => widget.blocks.add(block));
    _notify();
  }

  void _remove(int index) {
    setState(() => widget.blocks.removeAt(index));
    _notify();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= widget.blocks.length) return;
    setState(() {
      final block = widget.blocks.removeAt(index);
      widget.blocks.insert(target, block);
    });
    _notify();
  }

  Future<String?> _pickAndUpload() async {
    final file = await openFile(acceptedTypeGroups: const [_imagesTypeGroup]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final result = await widget.api.uploadImage(bytes, file.name);
    return result['hash'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.blocks.length; i++)
          _BlockRow(
            key: ObjectKey(widget.blocks[i]),
            block: widget.blocks[i],
            api: widget.api,
            onChanged: _notify,
            onDelete: () => _remove(i),
            onMoveUp: i == 0 ? null : () => _move(i, -1),
            onMoveDown: i == widget.blocks.length - 1 ? null : () => _move(i, 1),
            pickAndUpload: _pickAndUpload,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.notes, size: 18),
              label: Text(l10n.addParagraph),
              onPressed: () => _add({
                'type': 'paragraph',
                'spans': [
                  {'text': ''}
                ],
              }),
            ),
            ActionChip(
              avatar: const Icon(Icons.title, size: 18),
              label: Text(l10n.addHeading),
              onPressed: () => _add({'type': 'heading', 'text': ''}),
            ),
            ActionChip(
              avatar: const Icon(Icons.image, size: 18),
              label: Text(l10n.addImage),
              onPressed: () async {
                final hash = await _pickAndUpload();
                if (hash != null) {
                  _add({'type': 'image', 'image': hash, 'caption': null, 'placement': 'block'});
                }
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.grid_view, size: 18),
              label: Text(l10n.addImageGroup),
              onPressed: () => _add({'type': 'image_group', 'images': [], 'layout': 'grid'}),
            ),
            ActionChip(
              avatar: const Icon(Icons.table_chart, size: 18),
              label: Text(l10n.addTable),
              onPressed: () => _add({
                'type': 'table',
                'title': null,
                'header': [
                  {'text': ''},
                  {'text': ''},
                ],
                'rows': [
                  [
                    {'text': ''},
                    {'text': ''},
                  ],
                ],
              }),
            ),
          ],
        ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    super.key,
    required this.block,
    required this.api,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.pickAndUpload,
  });

  final ContentBlock block;
  final ApiClient api;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Future<String?> Function() pickAndUpload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Widget editor = switch (block['type'] as String?) {
      'paragraph' => _ParagraphEditor(block: block, onChanged: onChanged),
      'heading' => _HeadingEditor(block: block, onChanged: onChanged),
      'image' => _ImageEditor(block: block, api: api, onChanged: onChanged),
      'image_group' =>
        _ImageGroupEditor(block: block, api: api, onChanged: onChanged, pick: pickAndUpload),
      'table' => _TableEditor(block: block, onChanged: onChanged),
      _ => const SizedBox.shrink(),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: editor),
            Column(
              children: [
                IconButton(
                  tooltip: l10n.moveUp,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: onMoveUp,
                ),
                IconButton(
                  tooltip: l10n.moveDown,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: onMoveDown,
                ),
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paragraph text editing flattens spans to plain text. Legacy content has no
/// inline styling, so this is lossless in practice; styling survives untouched
/// paragraphs because unedited blocks are never rewritten.
class _ParagraphEditor extends StatefulWidget {
  const _ParagraphEditor({required this.block, required this.onChanged});

  final ContentBlock block;
  final VoidCallback onChanged;

  @override
  State<_ParagraphEditor> createState() => _ParagraphEditorState();
}

class _ParagraphEditorState extends State<_ParagraphEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final text = ((widget.block['spans'] as List? ?? const [])
        .map((s) => (s as Map)['text'] as String? ?? '')).join();
    _controller = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 12,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
      onChanged: (value) {
        widget.block['spans'] = [
          {'text': value}
        ];
        widget.onChanged();
      },
    );
  }
}

class _HeadingEditor extends StatefulWidget {
  const _HeadingEditor({required this.block, required this.onChanged});

  final ContentBlock block;
  final VoidCallback onChanged;

  @override
  State<_HeadingEditor> createState() => _HeadingEditorState();
}

class _HeadingEditorState extends State<_HeadingEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block['text'] as String? ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
      onChanged: (value) {
        widget.block['text'] = value;
        widget.onChanged();
      },
    );
  }
}

class _ImageEditor extends StatefulWidget {
  const _ImageEditor({required this.block, required this.api, required this.onChanged});

  final ContentBlock block;
  final ApiClient api;
  final VoidCallback onChanged;

  @override
  State<_ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<_ImageEditor> {
  late final TextEditingController _caption;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.block['caption'] as String? ?? '');
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hash = widget.block['image'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hash != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(widget.api.imageUrl(hash), height: 140),
          ),
        TextField(
          controller: _caption,
          decoration: InputDecoration(labelText: l10n.caption, isDense: true),
          onChanged: (value) {
            widget.block['caption'] = value.isEmpty ? null : value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        // Image positioning option (FR-019): beside text or as its own block.
        DropdownButton<String>(
          value: widget.block['placement'] as String? ?? 'block',
          items: [
            DropdownMenuItem(value: 'block', child: Text(l10n.placementBlock)),
            DropdownMenuItem(value: 'right', child: Text(l10n.placementRight)),
          ],
          onChanged: (value) {
            setState(() => widget.block['placement'] = value);
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

class _ImageGroupEditor extends StatefulWidget {
  const _ImageGroupEditor({
    required this.block,
    required this.api,
    required this.onChanged,
    required this.pick,
  });

  final ContentBlock block;
  final ApiClient api;
  final VoidCallback onChanged;
  final Future<String?> Function() pick;

  @override
  State<_ImageGroupEditor> createState() => _ImageGroupEditorState();
}

class _ImageGroupEditorState extends State<_ImageGroupEditor> {
  List<Map<String, dynamic>> get _images => (widget.block['images'] as List)
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final images = _images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < images.length; i++)
              Stack(
                children: [
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.api.imageUrl(images[i]['image'] as String),
                          height: 100,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: l10n.removeImage,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() => (widget.block['images'] as List).removeAt(i));
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ActionChip(
              avatar: const Icon(Icons.add_photo_alternate, size: 18),
              label: Text(l10n.addImage),
              onPressed: () async {
                final hash = await widget.pick();
                if (hash != null) {
                  setState(() =>
                      (widget.block['images'] as List).add({'image': hash, 'caption': null}));
                  widget.onChanged();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Grid layout option (FR-019).
        DropdownButton<String>(
          value: widget.block['layout'] as String? ?? 'grid',
          items: [
            DropdownMenuItem(value: 'grid', child: Text(l10n.layoutGrid)),
            DropdownMenuItem(value: 'row', child: Text(l10n.layoutRow)),
          ],
          onChanged: (value) {
            setState(() => widget.block['layout'] = value);
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

/// Table editing: title plus text cells; add row/column. Image cells from
/// legacy imports are preserved untouched and shown as a placeholder chip.
class _TableEditor extends StatefulWidget {
  const _TableEditor({required this.block, required this.onChanged});

  final ContentBlock block;
  final VoidCallback onChanged;

  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  List<List<Map<String, dynamic>>> get _rows => (widget.block['rows'] as List)
      .map((r) => (r as List).map((c) => (c as Map).cast<String, dynamic>()).toList())
      .toList();

  List<Map<String, dynamic>> get _header =>
      (widget.block['header'] as List).map((c) => (c as Map).cast<String, dynamic>()).toList();

  Widget _cellField(Map<String, dynamic> cell, {bool bold = false}) {
    if (cell['image'] != null) {
      return Chip(label: Text(cell['text'] as String? ?? 'imagen'));
    }
    return SizedBox(
      width: 140,
      child: TextFormField(
        initialValue: cell['text'] as String? ?? '',
        style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        decoration: const InputDecoration(isDense: true),
        onChanged: (value) {
          cell['text'] = value;
          widget.onChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: widget.block['title'] as String? ?? '',
          decoration: InputDecoration(labelText: l10n.tableTitle, isDense: true),
          onChanged: (value) {
            widget.block['title'] = value.isEmpty ? null : value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [for (final cell in _header) _cellField(cell, bold: true)]),
              for (final row in _rows) Row(children: [for (final cell in row) _cellField(cell)]),
            ],
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.table_rows, size: 18),
              label: Text(l10n.addRow),
              onPressed: () {
                final columns = _header.length;
                setState(() => (widget.block['rows'] as List)
                    .add([for (var i = 0; i < columns; i++) {'text': ''}]));
                widget.onChanged();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.view_column, size: 18),
              label: Text(l10n.addColumn),
              onPressed: () {
                setState(() {
                  (widget.block['header'] as List).add({'text': ''});
                  for (final row in widget.block['rows'] as List) {
                    (row as List).add({'text': ''});
                  }
                });
                widget.onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }
}
