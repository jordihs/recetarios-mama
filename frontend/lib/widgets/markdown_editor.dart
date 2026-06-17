import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/table_data.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor_codecs.dart';
import 'package:recetarios/widgets/table_editor_dialog.dart';

const _imagesTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
);

final _imageRef = RegExp(r'image://([0-9a-fA-F]{64})');

/// Rich text editor for one markdown document (research R3).
///
/// Markdown in / markdown out: the canonical representation never leaves this
/// widget's contract. WYSIWYG (appflowy_editor) is the default surface with a
/// toolbar (bold, italic, H2/H3, list, table, image) and an unobtrusive
/// "fuente" toggle to a raw monospace view (FR-010). Documents the WYSIWYG
/// cannot represent losslessly (e.g. tables with image cells) open in source
/// mode instead — the canonical markdown is never lossy-round-tripped.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.initialMarkdown,
    required this.api,
    required this.onChanged,
  });

  static const sourceFieldKey = Key('markdown_editor_source_field');

  final String initialMarkdown;
  final ApiClient api;
  final ValueChanged<String> onChanged;

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
  late String _markdown = widget.initialMarkdown;
  late final TextEditingController _sourceController =
      TextEditingController(text: widget.initialMarkdown);
  late bool _sourceMode = !_roundTripsSafely(widget.initialMarkdown);
  EditorState? _editor;
  StreamSubscription<void>? _subscription;
  late final EditorScrollController _scrollController;

  EditorState get editorState => _editor!;

  @override
  void initState() {
    super.initState();
    if (!_sourceMode) {
      _attachEditor(_markdown);
    }
    _scrollController = EditorScrollController(
      editorState: _editor ?? EditorState.blank(),
      shrinkWrap: true,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sourceController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- conversion

  /// `image://<hash>` → servable URL, so the WYSIWYG can display the image.
  String _toEditable(String markdown) => markdown.replaceAllMapped(
        _imageRef,
        (m) => widget.api.imageUrl(m.group(1)!),
      );

  /// Servable URL → canonical `image://<hash>`.
  String _toCanonical(String markdown) => markdown.replaceAllMapped(
        RegExp(RegExp.escape(widget.api.baseUrl) + r'/images/([0-9a-fA-F]{64})'),
        (m) => 'image://${m.group(1)!}',
      );

  Document _decode(String markdown) {
    final editable = _toEditable(markdown);
    final tableMds = _extractTableMarkdowns(editable);
    final decoded = markdownToDocument(
      editable,
      markdownParsers: const [CaptionedImageMarkdownParser()],
    );

    // Annotate each table node with its original canonical markdown.
    // _encodeNode() returns this verbatim instead of re-encoding through
    // appflowy's lossy table serialiser (which can't represent image cells).
    var ti = 0;
    final annotated = decoded.root.children.map((node) {
      if (node.type == TableBlockKeys.type && ti < tableMds.length) {
        final canonical = _toCanonical(tableMds[ti]);
        ti++;
        return node.copyWith(attributes: {
          ...node.attributes,
          tableMarkdownKey: canonical,
          tableIndexKey: ti,
        });
      }
      return node.deepCopy();
    }).toList();

    // Ensure the document never ends with a table: the placeholder has no
    // natural "click below" target, so we guarantee at least one paragraph
    // after the last table for the user to continue typing.
    if (annotated.isNotEmpty &&
        annotated.last.type == TableBlockKeys.type) {
      annotated.add(paragraphNode());
    }

    final result = Document.blank();
    if (annotated.isEmpty) {
      result.insert([0], [paragraphNode()]);
    } else {
      result.insert([0], annotated);
    }
    return result;
  }

  /// Extracts the raw text of every GFM table block found in [markdown].
  /// Blocks are separated by blank lines; a block is a table when its first
  /// line starts with `|` and its second line is a delimiter row (`:?-+:?`).
  List<String> _extractTableMarkdowns(String markdown) {
    final tables = <String>[];
    for (final chunk in markdown.split(RegExp(r'\n{2,}'))) {
      final block = chunk.trim();
      if (block.isEmpty) continue;
      final lines = block.split('\n');
      if (lines.length < 2) continue;
      if (!lines[0].trim().startsWith('|')) continue;
      final delimCells = _parseTableRowCells(lines[1].trim());
      if (delimCells.isNotEmpty &&
          delimCells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
        tables.add(block);
      }
    }
    return tables;
  }

  List<String> _parseTableRowCells(String line) {
    if (!line.startsWith('|')) return [];
    final parts = line.split('|');
    final start = parts.first.trim().isEmpty ? 1 : 0;
    final end = parts.last.trim().isEmpty ? parts.length - 1 : parts.length;
    if (start >= end) return [];
    return parts.sublist(start, end).map((s) => s.trim()).toList();
  }

  String _encode(Document document) =>
      _toCanonical(encodeDocumentToMarkdown(document)).trim();

  /// True when WYSIWYG decode→encode preserves the document's semantics
  /// (compared as GFM HTML, so cosmetic syntax differences don't count).
  bool _roundTripsSafely(String markdown) {
    if (markdown.trim().isEmpty) {
      return true;
    }
    try {
      final roundTripped = _encode(_decode(markdown));
      String html(String source) => md
          .markdownToHtml(source, extensionSet: md.ExtensionSet.gitHubFlavored)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return html(roundTripped) == html(markdown);
    } catch (_) {
      return false;
    }
  }

  void _attachEditor(String markdown) {
    _subscription?.cancel();
    final editor = EditorState(document: _decode(markdown));
    _subscription = editor.transactionStream
        .where((event) => event.$1 == TransactionTime.after)
        .listen((_) => _emitFromEditor());
    _editor = editor;
  }

  void _emitFromEditor() {
    final editor = _editor;
    if (editor == null) {
      return;
    }
    _markdown = _encode(editor.document);
    _sourceController.text = _markdown;
    widget.onChanged(_markdown);
  }

  // -------------------------------------------------- table editor callback

  Future<void> _openTableEditor(BuildContext ctx, Node tableNode) async {
    final storedMd =
        tableNode.attributes[tableMarkdownKey] as String? ?? '';
    // Compute the 1-based table position from the live document so the dialog
    // title stays accurate even when tables have been added or removed.
    var index = 0;
    for (final n in (_editor?.document.root.children ?? <Node>[])) {
      if (n.type == TableBlockKeys.type) index++;
      if (n.id == tableNode.id) break;
    }
    if (index == 0) index = 1;
    final initial = storedMd.isEmpty
        ? TableData.blank()
        : TableData.fromMarkdown(storedMd);
    final result =
        await TableEditorDialog.show(ctx, initial, widget.api, index);
    if (result == null || !mounted) return;
    final editor = _editor;
    if (editor == null) return;
    final transaction = editor.transaction
      ..updateNode(tableNode, {tableMarkdownKey: result.toMarkdown()});
    await editor.apply(transaction);
    _emitFromEditor();
  }

  // ----------------------------------------------------------- mode switch

  void _toggleSource() {
    final l10n = AppLocalizations.of(context)!;
    if (_sourceMode) {
      if (!_roundTripsSafely(_markdown)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.editorSourceOnly)),
        );
        return;
      }
      setState(() {
        _attachEditor(_markdown);
        _sourceMode = false;
      });
    } else {
      _sourceController.text = _markdown;
      setState(() => _sourceMode = true);
    }
  }

  // -------------------------------------------------------- toolbar actions

  Future<void> toggleBold() =>
      editorState.toggleAttribute(AppFlowyRichTextKeys.bold);

  Future<void> toggleItalic() =>
      editorState.toggleAttribute(AppFlowyRichTextKeys.italic);

  Future<void> formatHeading(int level) => editorState.formatNode(
        null,
        (node) => headingNode(level: level, delta: node.delta ?? Delta()),
      );

  Future<void> toggleBulletedList() => editorState.formatNode(
        null,
        (node) => node.type == BulletedListBlockKeys.type
            ? paragraphNode(delta: node.delta ?? Delta())
            : bulletedListNode(delta: node.delta ?? Delta()),
      );

  Future<void> insertTable() async {
    final editor = _editor;
    if (editor == null) return;
    final path = editor.selection?.end.path;
    final insertAt = path == null || path.isEmpty
        ? [editor.document.root.children.length]
        : [path.first + 1];
    final tableNodes = _decode('| Columna | Columna |\n| --- | --- |\n|  |  |')
        .root.children.map((n) => n.deepCopy()).toList();
    // Always follow the table with an empty paragraph so the user has
    // somewhere to type without needing to switch to source mode.
    final transaction = editor.transaction
      ..insertNodes(insertAt, [...tableNodes, paragraphNode()]);
    await editor.apply(transaction);
  }

  // Public: called from tests with the editor focused — uses current selection.
  Future<void> insertImageReference(String hash, {String caption = ''}) =>
      _doInsertImage(hash, caption: caption, sel: _editor?.selection);

  // Core insertion: uses [sel] so callers can pass a snapshot taken before
  // any async gap that would clear the editor's focus/selection.
  Future<void> _doInsertImage(
    String hash, {
    String caption = '',
    Selection? sel,
  }) async {
    final editor = _editor;
    if (editor == null) return;
    // Inside a table cell, images can't be block nodes — insert as inline
    // markdown text in the cell's paragraph delta so the reference stays in
    // the cell as valid GFM inline-image syntax.
    if (sel != null && _selInTableCell(editor, sel)) {
      final node = editor.getNodeAtPath(sel.end.path);
      if (node == null) return;
      final transaction = editor.transaction
        ..insertText(node, sel.end.offset, '![$caption](image://$hash)');
      await editor.apply(transaction);
      return;
    }
    await _insertMarkdownSnippet('![$caption](image://$hash)', sel: sel);
  }

  bool _selInTableCell(EditorState editor, Selection sel) {
    final path = sel.end.path;
    if (path.length < 2) return false;
    return editor.getNodeAtPath([path[0]])?.type == TableBlockKeys.type;
  }

  Future<void> _insertMarkdownSnippet(String snippet, {Selection? sel}) async {
    final editor = _editor;
    if (editor == null) return;
    final nodes = _decode(snippet).root.children.map((n) => n.deepCopy()).toList();
    final path = (sel ?? editor.selection)?.end.path;
    final insertAt = path == null || path.isEmpty
        ? [editor.document.root.children.length]
        : [path.first + 1];
    final transaction = editor.transaction..insertNodes(insertAt, nodes);
    await editor.apply(transaction);
  }

  Future<void> _pickAndInsertImage() async {
    final editor = _editor;
    if (editor == null) return;
    // Snapshot selection NOW — the file-picker dialog will cause the editor
    // to lose focus, clearing editor.selection before we can use it.
    final sel = editor.selection;
    final file = await openFile(acceptedTypeGroups: const [_imagesTypeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final result = await widget.api.uploadImage(bytes, file.name);
    await _doInsertImage(result['hash'] as String, sel: sel);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                if (!_sourceMode) ...[
                  _action(Icons.format_bold, l10n.editorBold, toggleBold),
                  _action(Icons.format_italic, l10n.editorItalic, toggleItalic),
                  _action(Icons.title, l10n.editorH2, () => formatHeading(2)),
                  _action(
                      Icons.text_fields, l10n.editorH3, () => formatHeading(3)),
                  _action(Icons.format_list_bulleted, l10n.editorBulletedList,
                      toggleBulletedList),
                  _action(Icons.table_chart_outlined, l10n.editorInsertTable,
                      insertTable),
                  _action(Icons.image_outlined, l10n.editorInsertImage,
                      _pickAndInsertImage),
                ],
                const Spacer(),
                // Unobtrusive source toggle (FR-010): small, end of the bar.
                Semantics(
                  button: true,
                  label: l10n.editorSource,
                  child: IconButton(
                    tooltip: l10n.editorSource,
                    iconSize: 18,
                    icon: Icon(
                      Icons.code,
                      color: _sourceMode ? theme.colorScheme.primary : null,
                    ),
                    onPressed: _toggleSource,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160, maxHeight: 420),
            child: _sourceMode ? _sourceField() : _wysiwyg(),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        iconSize: 20,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }

  Widget _sourceField() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        key: MarkdownEditor.sourceFieldKey,
        controller: _sourceController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(border: InputBorder.none),
        onChanged: (value) {
          _markdown = value;
          widget.onChanged(value);
        },
      ),
    );
  }

  Widget _wysiwyg() {
    return AppFlowyEditor(
      editorState: editorState,
      shrinkWrap: true,
      editorScrollController: _scrollController,
      editorStyle: EditorStyle.desktop(
        padding: const EdgeInsets.all(12),
        cursorColor: Theme.of(context).colorScheme.primary,
        selectionColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
      ),
      blockComponentBuilders: {
        ...standardBlockComponentBuilderMap,
        // Replace the stock table renderer with a placeholder; the real
        // table UI is the dedicated TableEditorDialog (double-click to open).
        TableBlockKeys.type: _TablePlaceholderBlockComponentBuilder(
          onEdit: _openTableEditor,
        ),
      },
      // Intercept Enter on a focused table placeholder before the standard
      // handler can mutate the table node structure.
      commandShortcutEvents: [
        CommandShortcutEvent(
          key: 'table placeholder enter',
          getDescription: () => 'Open table editor on Enter',
          command: 'enter',
          handler: (editorState) {
            final sel = editorState.selection;
            if (sel == null) return KeyEventResult.ignored;
            final node = editorState.getNodeAtPath(sel.start.path);
            if (node?.type != TableBlockKeys.type) {
              return KeyEventResult.ignored;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openTableEditor(context, node!);
            });
            return KeyEventResult.handled;
          },
        ),
        ...standardCommandShortcutEvents,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Table placeholder block component
// ---------------------------------------------------------------------------

/// Registers our custom table placeholder under the `table` key, replacing
/// appflowy's stock table renderer. The placeholder is a styled text line that
/// the user double-clicks to open the [TableEditorDialog].
class _TablePlaceholderBlockComponentBuilder extends BlockComponentBuilder {
  _TablePlaceholderBlockComponentBuilder({required this.onEdit});

  final Future<void> Function(BuildContext context, Node node) onEdit;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _TablePlaceholderWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      onEdit: (ctx) => onEdit(ctx, node),
    );
  }

  // Tables always have children (cells), so the stock validate would reject
  // them. Accept any table node unconditionally.
  @override
  BlockComponentValidate get validate => (_) => true;
}

class _TablePlaceholderWidget extends BlockComponentStatefulWidget {
  const _TablePlaceholderWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    this.onEdit,
  });

  final Future<void> Function(BuildContext context)? onEdit;

  @override
  State<_TablePlaceholderWidget> createState() =>
      _TablePlaceholderWidgetState();
}

class _TablePlaceholderWidgetState extends State<_TablePlaceholderWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final _innerKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    // Count 1-based position of this table among all table nodes in the
    // document — do not rely on the stored tableIndexKey attribute which is
    // always 1 for newly inserted single-table snippets.
    var index = 0;
    for (final n in editorState.document.root.children) {
      if (n.type == TableBlockKeys.type) index++;
      if (n.id == widget.node.id) break;
    }
    if (index == 0) index = 1;

    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => widget.onEdit?.call(context),
      child: Padding(
        key: _innerKey,
        padding: padding,
        child: Text(
          '[Tabla $index. Haga doble clic para ver/editar]',
          style: const TextStyle(
            color: Color(0xFFCC0000),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
        BlockSelectionType.cursor,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return getRectsInSelection(Selection.invalid()).firstOrNull ?? Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return null;
    return getRectsInSelection(
      Selection.collapsed(position),
      shiftWithBaseOffset: shiftWithBaseOffset,
    ).firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return [];
    final parentBox = context.findRenderObject();
    final innerBox = _innerKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && innerBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? innerBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            innerBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);

  @override
  TextDirection textDirection() => TextDirection.ltr;
}
