import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/table_data.dart';
import 'package:recetarios/features/books/book_form_screen.dart' show imagesTypeGroup;

// ---------------------------------------------------------------------------
// Cell-block model
// ---------------------------------------------------------------------------

sealed class _CellBlock {
  const _CellBlock();
}

/// A text segment inside a cell.  Owns its [TextEditingController] and
/// [FocusNode]; call [dispose] when removing the block.
final class _TextBlock extends _CellBlock {
  _TextBlock([String initial = ''])
      : controller = TextEditingController(text: initial),
        focusNode = FocusNode();

  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// An image segment inside a cell.  Immutable; no resources to release.
final class _ImageBlock extends _CellBlock {
  const _ImageBlock(this.hash, {this.caption = ''});
  final String hash;
  final String caption;
}

// ---------------------------------------------------------------------------
// Block ↔ cell-content string conversion
// ---------------------------------------------------------------------------

/// Parses a flat cell-content string (with real `\n` for newlines, as stored
/// by [TableData]) into an ordered list of blocks.  Image references are
/// extracted as [_ImageBlock]s; surrounding text becomes [_TextBlock]s.
/// The list always ends with a [_TextBlock] so the user has a place to type.
List<_CellBlock> _parseBlocks(String content) {
  final blocks = <_CellBlock>[];
  final imageRe = RegExp(r'!\[([^\]]*)\]\(image://([0-9a-f]+)\)');
  var pos = 0;
  for (final m in imageRe.allMatches(content)) {
    final text =
        content.substring(pos, m.start).replaceAll(RegExp(r'^\n+|\n+$'), '');
    if (text.isNotEmpty) blocks.add(_TextBlock(text));
    blocks.add(_ImageBlock(m.group(2)!, caption: m.group(1) ?? ''));
    pos = m.end;
  }
  final tail =
      content.substring(pos).replaceAll(RegExp(r'^\n+|\n+$'), '');
  if (tail.isNotEmpty) blocks.add(_TextBlock(tail));
  if (blocks.isEmpty || blocks.last is _ImageBlock) blocks.add(_TextBlock());
  return blocks;
}

/// Renders blocks back to a flat cell-content string (with real `\n`).
/// Empty text blocks are omitted; segments are joined with `\n`.
String _blocksToContent(List<_CellBlock> blocks) {
  final parts = <String>[];
  for (final block in blocks) {
    switch (block) {
      case _TextBlock(:final controller):
        final t = controller.text;
        if (t.isNotEmpty) parts.add(t);
      case _ImageBlock(:final hash, :final caption):
        parts.add('![$caption](image://$hash)');
    }
  }
  return parts.join('\n');
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------

/// Full-screen dialog for editing a GFM table.
///
/// Cells are rendered as ordered lists of image thumbnails and text fields,
/// matching the visual structure the user will see in view mode.  Images can
/// be inserted after any text block; each image block has a delete button.
class TableEditorDialog extends StatefulWidget {
  const TableEditorDialog({
    super.key,
    required this.initial,
    required this.api,
    required this.tableIndex,
  });

  final TableData initial;
  final ApiClient api;
  final int tableIndex;

  static Future<TableData?> show(
    BuildContext context,
    TableData initial,
    ApiClient api,
    int tableIndex,
  ) {
    return showDialog<TableData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        child: TableEditorDialog(
          initial: initial,
          api: api,
          tableIndex: tableIndex,
        ),
      ),
    );
  }

  @override
  State<TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<TableEditorDialog> {
  // [row][col] → ordered list of content blocks
  late List<List<List<_CellBlock>>> _blocks;

  int get _rowCount => _blocks.length;
  int get _colCount => _blocks.isEmpty ? 0 : _blocks[0].length;

  @override
  void initState() {
    super.initState();
    _blocks = _toBlocks(widget.initial);
  }

  @override
  void dispose() {
    _disposeAll(_blocks);
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  List<List<List<_CellBlock>>> _toBlocks(TableData data) => [
        for (final row in data.cells)
          [for (final content in row) _parseBlocks(content)],
      ];

  void _disposeAll(List<List<List<_CellBlock>>> blocks) {
    for (final row in blocks) {
      for (final cell in row) {
        for (final block in cell) {
          if (block is _TextBlock) block.dispose();
        }
      }
    }
  }

  TableData _currentData() => TableData(cells: [
        for (final row in _blocks)
          [for (final cell in row) _blocksToContent(cell)],
      ]);

  /// Flushes current text → applies a structural mutation → rebuilds blocks.
  void _applyStructure(TableData Function(TableData) fn) {
    final old = _blocks;
    final next = _toBlocks(fn(_currentData()));
    setState(() => _blocks = next);
    // Dispose old blocks after setState so the rebuild uses the new ones.
    _disposeAll(old);
  }

  // ---------------------------------------------------------------- mutations

  /// Uploads a file and inserts an [_ImageBlock] + a new empty [_TextBlock]
  /// immediately after [blockIdx] in cell ([row], [col]).
  Future<void> _insertImageAfterBlock(int row, int col, int blockIdx) async {
    final file = await openFile(acceptedTypeGroups: const [imagesTypeGroup]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final result = await widget.api.uploadImage(bytes, file.name);
    if (!mounted) return;
    final hash = result['hash'] as String;
    setState(() {
      _blocks[row][col].insertAll(blockIdx + 1, [_ImageBlock(hash), _TextBlock()]);
    });
  }

  void _removeImageBlock(int row, int col, int blockIdx) {
    setState(() {
      final cell = _blocks[row][col];
      cell.removeAt(blockIdx);
      // Ensure at least one text block remains so the cell stays editable.
      if (cell.isEmpty || cell.every((b) => b is _ImageBlock)) {
        cell.add(_TextBlock());
      }
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Tabla ${widget.tableIndex}'),
        leading: IconButton(
          tooltip: 'Cancelar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_currentData()),
            child: const Text('Aceptar'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Structural toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add, size: 16),
                  label: const Text('Añadir fila'),
                  onPressed: () => _applyStructure((d) => d.addRow()),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.view_column_outlined, size: 16),
                  label: const Text('Añadir columna'),
                  onPressed: () => _applyStructure((d) => d.addColumn()),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Eliminar última fila'),
                  onPressed: _rowCount <= 1
                      ? null
                      : () => _applyStructure((d) => d.removeLastRow()),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Eliminar última columna'),
                  onPressed: _colCount <= 1
                      ? null
                      : () => _applyStructure((d) => d.removeLastColumn()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable cell grid
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(color: theme.dividerColor),
                    defaultColumnWidth: const FixedColumnWidth(200),
                    children: [
                      for (var r = 0; r < _rowCount; r++)
                        TableRow(
                          decoration: r == 0
                              ? BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                )
                              : null,
                          children: [
                            for (var c = 0; c < _colCount; c++)
                              _buildCell(r, c),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final blocks = _blocks[row][col];
    final isHeader = row == 0;
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.top,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < blocks.length; i++)
              _buildBlock(row, col, i, blocks[i], isHeader),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(int row, int col, int idx, _CellBlock block, bool isHeader) {
    if (block is _ImageBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                widget.api.imageUrl(block.hash),
                width: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 160,
                  height: 80,
                  child: ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 12, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                ),
                tooltip: 'Eliminar imagen',
                onPressed: () => _removeImageBlock(row, col, idx),
              ),
            ),
          ],
        ),
      );
    }

    // Text block: text field + "insert image after this block" button
    final textBlock = block as _TextBlock;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: textBlock.controller,
            focusNode: textBlock.focusNode,
            maxLines: null,
            minLines: 2,
            style: isHeader ? const TextStyle(fontWeight: FontWeight.bold) : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          tooltip: 'Insertar imagen aquí',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          onPressed: () => _insertImageAfterBlock(row, col, idx),
        ),
      ],
    );
  }
}
