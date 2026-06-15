/// Markdown ⇄ appflowy document conversion tuned to this app's conventions.
///
/// The stock codec is lossy in ways that matter here: it separates blocks
/// with a single newline (merging adjacent paragraphs on re-decode), drops
/// image alt text (our captions), and can't represent gallery paragraphs
/// (consecutive image lines). These helpers fix all three so that real
/// imported content round-trips and can be edited in WYSIWYG mode.
library;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

const _altKey = 'alt';
const _galleryKey = 'galleryGroup';

int _galleryCounter = 0;

/// Decode parser: standalone images and image-only paragraphs (galleries)
/// become image nodes, preserving the alt text (the caption). Images from
/// the same gallery paragraph share a group id so the encoder can put them
/// back into one paragraph — and only them.
class CaptionedImageMarkdownParser extends CustomMarkdownParser {
  const CaptionedImageMarkdownParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }
    if (element.tag == 'img' && element.attributes['src'] != null) {
      return [_imageNode(element)];
    }
    if (element.tag != 'p') {
      return [];
    }
    final children = element.children ?? const [];
    final images = children
        .whereType<md.Element>()
        .where((e) => e.tag == 'img' && e.attributes['src'] != null)
        .toList();
    if (images.isEmpty) {
      return [];
    }
    final otherText = children
        .where((c) => !(c is md.Element && c.tag == 'img'))
        .map((c) => c.textContent)
        .join()
        .trim();
    if (otherText.isNotEmpty) {
      return []; // mixed text+image paragraphs: leave to the text parser
    }
    // One node per image; a multi-image paragraph is a gallery whose
    // members share a group id.
    final group = images.length > 1 ? ++_galleryCounter : null;
    return [for (final image in images) _imageNode(image, group: group)];
  }

  Node _imageNode(md.Element image, {int? group}) {
    final node = imageNode(url: image.attributes['src']!);
    final alt = image.attributes['alt'] ?? '';
    return node.copyWith(attributes: {
      ...node.attributes,
      _altKey: alt,
      _galleryKey: group,
    });
  }
}

/// Image markdown line including the caption (alt text).
String imageNodeToMarkdown(Node node) {
  final alt = node.attributes[_altKey] as String? ?? '';
  final url = node.attributes[ImageBlockKeys.url] as String? ?? '';
  return '![$alt]($url)';
}

const _listTypes = {
  BulletedListBlockKeys.type,
  NumberedListBlockKeys.type,
  TodoListBlockKeys.type,
};

/// Encode a document to markdown with correct block separation:
/// blank line between blocks, single newline inside list runs (keeps lists
/// tight) and inside image runs (keeps galleries one paragraph).
String encodeDocumentToMarkdown(Document document) {
  final children = document.root.children.toList();
  final buffer = StringBuffer();
  Node? previous;
  for (final node in children) {
    final part = _encodeNode(node);
    if (part.isEmpty) {
      continue;
    }
    if (previous != null) {
      buffer.write(_separator(previous, node));
    }
    buffer.write(part);
    previous = node;
  }
  return buffer.toString().trim();
}

String _encodeNode(Node node) {
  if (node.type == ImageBlockKeys.type) {
    return imageNodeToMarkdown(node);
  }
  return documentToMarkdown(
    Document(root: pageNode(children: [node.deepCopy()])),
  ).trimRight();
}

String _separator(Node a, Node b) {
  if (a.type == b.type && _listTypes.contains(a.type)) {
    return '\n';
  }
  // Members of the same gallery stay on consecutive lines (one paragraph);
  // unrelated adjacent images remain separate paragraphs.
  if (a.type == ImageBlockKeys.type &&
      b.type == ImageBlockKeys.type &&
      a.attributes[_galleryKey] != null &&
      a.attributes[_galleryKey] == b.attributes[_galleryKey]) {
    return '\n';
  }
  return '\n\n';
}
