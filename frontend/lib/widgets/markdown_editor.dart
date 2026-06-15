import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor_codecs.dart';

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
    final document = markdownToDocument(
      _toEditable(markdown),
      markdownParsers: const [CaptionedImageMarkdownParser()],
    );
    if (document.root.children.isEmpty) {
      document.insert([0], [paragraphNode()]);
    }
    return document;
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

  Future<void> insertTable() => _insertMarkdownSnippet(
        '| Columna | Columna |\n| --- | --- |\n|  |  |',
      );

  Future<void> insertImageReference(String hash, {String caption = ''}) =>
      _insertMarkdownSnippet('![$caption](image://$hash)');

  Future<void> _insertMarkdownSnippet(String snippet) async {
    final editor = _editor;
    if (editor == null) {
      return;
    }
    final nodes = _decode(snippet).root.children.map((n) => n.deepCopy()).toList();
    final path = editor.selection?.end.path;
    final insertAt = path == null || path.isEmpty
        ? [editor.document.root.children.length]
        : [path.first + 1];
    final transaction = editor.transaction..insertNodes(insertAt, nodes);
    await editor.apply(transaction);
  }

  Future<void> _pickAndInsertImage() async {
    final file = await openFile(acceptedTypeGroups: const [_imagesTypeGroup]);
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    final result = await widget.api.uploadImage(bytes, file.name);
    await insertImageReference(result['hash'] as String);
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
    );
  }
}
