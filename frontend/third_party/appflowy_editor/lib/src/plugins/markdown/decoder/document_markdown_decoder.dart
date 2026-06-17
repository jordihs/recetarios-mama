import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/plugins/markdown/decoder/custom_syntaxes/underline_syntax.dart';
import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;

import 'custom_syntaxes/formula_syntax.dart';

class DocumentMarkdownDecoder extends Converter<String, Document> {
  DocumentMarkdownDecoder({
    this.markdownElementParsers = const [],
    this.inlineSyntaxes = const [],
  });

  final List<CustomMarkdownParser> markdownElementParsers;
  final List<md.InlineSyntax> inlineSyntaxes;

  @override
  Document convert(String input) {
    final formattedMarkdown = _formatMarkdown(input);
    final List<md.Node> mdNodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        ...inlineSyntaxes,
        FormulaInlineSyntax(),
        UnderlineInlineSyntax(),
      ],
      encodeHtml: false,
    ).parse(formattedMarkdown);

    final document = Document.blank();
    final nodes = mdNodes
        .map((e) => _parseNode(e))
        .nonNulls
        .flattened
        .toList(growable: false); // avoid lazy evaluation
    if (nodes.isNotEmpty) {
      document.insert([0], nodes);
    }

    return document;
  }

  // handle node itself and its children
  List<Node> _parseNode(md.Node mdNode) {
    List<Node> nodes = [];

    for (final parser in markdownElementParsers) {
      nodes = parser.transform(
        mdNode,
        markdownElementParsers,
      );

      if (nodes.isNotEmpty) {
        break;
      }
    }

    if (nodes.isEmpty) {
      AppFlowyEditorLog.editor.debug(
        'empty result from node: $mdNode, text: ${mdNode.textContent}',
      );
    }

    return nodes;
  }

  String _formatMarkdown(String markdown) {
    // Rule 1: single '\n' between text and image, add double '\n'.
    // Excludes ')' from the preceding-character match so that consecutive
    // image lines (galleries) are preserved: images end with ')', so
    // image-after-image is ')'\n'![' which this rule intentionally skips.
    String result = markdown.replaceAllMapped(
      RegExp(r'([^\n)])\n!\[([^\]]*)\]\(([^)]+)\)', multiLine: true),
      (match) {
        final text = match[1] ?? '';
        final altText = match[2] ?? '';
        final url = match[3] ?? '';
        return '$text\n\n![$altText]($url)';
      },
    );

    // Rule 2: without '\n' between text and image, add double '\n'.
    // Applied line-by-line, skipping table rows (lines that start with '|')
    // so that image references inside cells are not broken into separate blocks.
    result = result.splitMapJoin(
      RegExp(r'^.*$', multiLine: true),
      onMatch: (m) {
        final line = m.group(0)!;
        if (line.trimLeft().startsWith('|')) return line;
        return line.replaceAllMapped(
          RegExp(r'([^\n])!\[([^\]]*)\]\(([^)]+)\)'),
          (m) => '${m[1]}\n\n![${m[2]}](${m[3]})',
        );
      },
      onNonMatch: (s) => s,
    );

    // Add another rules here.

    return result;
  }
}
