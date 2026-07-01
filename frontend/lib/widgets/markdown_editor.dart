import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import 'package:recetarios/data/local/image_store.dart';
import 'package:recetarios/data/table_data.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor_codecs.dart';
import 'package:recetarios/widgets/table_editor_dialog.dart';

const _imagesTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
);

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
    required this.imageStore,
    required this.onChanged,
  });

  static const sourceFieldKey = Key('markdown_editor_source_field');

  final String initialMarkdown;
  final ImageStore imageStore;
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
  //
  // With local storage, image://hash URLs stay as-is in the editor document;
  // no HTTP URL expansion/contraction is needed. The custom image block
  // renderer in _wysiwyg() handles file loading by hash.

  Document _decode(String markdown) {
    final tableMds = _extractTableMarkdowns(markdown);
    final decoded = markdownToDocument(
      markdown,
      markdownParsers: const [CaptionedImageMarkdownParser()],
    );

    var ti = 0;
    final annotated = decoded.root.children.map((node) {
      if (node.type == TableBlockKeys.type && ti < tableMds.length) {
        ti++;
        return node.copyWith(attributes: {
          ...node.attributes,
          tableMarkdownKey: tableMds[ti - 1],
          tableIndexKey: ti,
        });
      }
      return node.deepCopy();
    }).toList();

    if (annotated.isNotEmpty && annotated.last.type == TableBlockKeys.type) {
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
      encodeDocumentToMarkdown(document).trim();

  bool _roundTripsSafely(String markdown) {
    if (markdown.trim().isEmpty) return true;
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
    if (editor == null) return;
    _markdown = _encode(editor.document);
    _sourceController.text = _markdown;
    widget.onChanged(_markdown);
  }

  // -------------------------------------------------- table editor callback

  Future<void> _openTableEditor(BuildContext ctx, Node tableNode) async {
    final storedMd = tableNode.attributes[tableMarkdownKey] as String? ?? '';
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
        await TableEditorDialog.show(ctx, initial, widget.imageStore, index);
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
    final transaction = editor.transaction
      ..insertNodes(insertAt, [...tableNodes, paragraphNode()]);
    await editor.apply(transaction);
  }

  Future<void> insertImageReference(String hash, {String caption = ''}) =>
      _doInsertImage(hash, caption: caption, sel: _editor?.selection);

  Future<void> _doInsertImage(
    String hash, {
    String caption = '',
    Selection? sel,
  }) async {
    final editor = _editor;
    if (editor == null) return;
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
    final sel = editor.selection;
    final file = await openFile(acceptedTypeGroups: const [_imagesTypeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final result = await widget.imageStore.ingest(bytes);
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
        TableBlockKeys.type: _TablePlaceholderBlockComponentBuilder(
          onEdit: _openTableEditor,
        ),
        ImageBlockKeys.type: _LocalImageBlockComponentBuilder(
          imageStore: widget.imageStore,
        ),
      },
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
// Local image block component
// ---------------------------------------------------------------------------

class _LocalImageBlockComponentBuilder extends BlockComponentBuilder {
  _LocalImageBlockComponentBuilder({required this.imageStore});

  final ImageStore imageStore;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    final url = node.attributes[ImageBlockKeys.url] as String? ?? '';
    String? filePath;
    if (url.startsWith('image://')) {
      filePath = imageStore.pathFor(url.substring('image://'.length));
    }
    final caption = node.attributes['alt'] as String? ?? '';
    return _LocalImageWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (ctx, state) => actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (ctx, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      filePath: filePath,
      caption: caption,
    );
  }

  @override
  BlockComponentValidate get validate => (_) => true;
}

class _LocalImageWidget extends BlockComponentStatefulWidget {
  const _LocalImageWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    this.filePath,
    this.caption = '',
  });

  final String? filePath;
  final String caption;

  @override
  State<_LocalImageWidget> createState() => _LocalImageWidgetState();
}

class _LocalImageWidgetState extends State<_LocalImageWidget>
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

    Widget child = Padding(
      key: _innerKey,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.filePath != null
                ? Image.file(
                    File(widget.filePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _BrokenImage(),
                  )
                : const _BrokenImage(),
          ),
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.caption,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
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
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      getRectsInSelection(Selection.invalid()).firstOrNull ?? Rect.zero;

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

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 60,
        height: 60,
        child: ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)),
      );
}

// ---------------------------------------------------------------------------
// Table placeholder block component (unchanged from original)
// ---------------------------------------------------------------------------

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
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      getRectsInSelection(Selection.invalid()).firstOrNull ?? Rect.zero;

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
