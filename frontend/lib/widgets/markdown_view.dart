import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:recetarios/data/api_client.dart';

/// Read-only renderer for canonical markdown content (CommonMark + GFM
/// tables). Conventions per the feature 003 data model: `##`/`###` headings,
/// `image://<hash>` image URIs whose alt text is the caption, paragraphs of
/// consecutive images rendered as a grid, optional bold title line above a
/// table, and `-` bullet lists.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.markdown, required this.api});

  final String markdown;
  final ApiClient api;

  static const _imageUriPrefix = 'image://';

  @override
  Widget build(BuildContext context) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    final nodes = document.parse(markdown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          if (_render(context, node) case final widget?)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: widget),
      ],
    );
  }

  Widget? _render(BuildContext context, md.Node node) {
    if (node is! md.Element) {
      final text = node.textContent.trim();
      return text.isEmpty ? null : Text(text);
    }
    switch (node.tag) {
      case 'h1':
      case 'h2':
        return Text(node.textContent, style: Theme.of(context).textTheme.titleLarge);
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return Text(node.textContent, style: Theme.of(context).textTheme.titleMedium);
      case 'p':
        return _paragraph(context, node);
      case 'ul':
      case 'ol':
        return _list(context, node);
      case 'table':
        return _table(context, node);
      default:
        final text = node.textContent.trim();
        return text.isEmpty ? null : Text(text);
    }
  }

  // ---------------------------------------------------------------- inline

  List<md.Element> _inlineImages(md.Element element) {
    final images = <md.Element>[];
    void walk(md.Node node) {
      if (node is md.Element) {
        if (node.tag == 'img') {
          images.add(node);
        } else {
          node.children?.forEach(walk);
        }
      }
    }

    element.children?.forEach(walk);
    return images;
  }

  bool _isImagesOnly(md.Element element) {
    final children = element.children ?? const [];
    if (children.isEmpty) return false;
    var hasImage = false;
    for (final child in children) {
      if (child is md.Element && child.tag == 'img') {
        hasImage = true;
      } else if (child.textContent.trim().isNotEmpty) {
        return false;
      }
    }
    return hasImage;
  }

  TextSpan _inlineSpan(md.Node node, {TextStyle style = const TextStyle()}) {
    if (node is! md.Element) {
      return TextSpan(text: node.textContent, style: style);
    }
    final next = switch (node.tag) {
      'strong' => style.merge(const TextStyle(fontWeight: FontWeight.bold)),
      'em' => style.merge(const TextStyle(fontStyle: FontStyle.italic)),
      _ => style,
    };
    if (node.tag == 'img') return const TextSpan();
    return TextSpan(
      children: [
        for (final child in node.children ?? const <md.Node>[])
          _inlineSpan(child, style: next),
      ],
      style: next,
    );
  }

  Widget _richText(BuildContext context, md.Element element) {
    return Text.rich(
      TextSpan(
        children: [
          for (final child in element.children ?? const <md.Node>[])
            _inlineSpan(child),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  // ---------------------------------------------------------------- blocks

  Widget? _paragraph(BuildContext context, md.Element element) {
    final images = _inlineImages(element);
    if (images.isEmpty) {
      return element.textContent.trim().isEmpty ? null : _richText(context, element);
    }
    if (_isImagesOnly(element)) {
      return images.length == 1
          ? _captionedImage(context, images.single)
          : _imageGrid(context, images);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _richText(context, element),
        const SizedBox(height: 8),
        if (images.length == 1)
          _captionedImage(context, images.single)
        else
          _imageGrid(context, images),
      ],
    );
  }

  Widget _captionedImage(BuildContext context, md.Element image) {
    final src = image.attributes['src'] ?? '';
    if (!src.startsWith(_imageUriPrefix)) return const SizedBox.shrink();
    final hash = src.substring(_imageUriPrefix.length);
    final caption = image.attributes['alt'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            api.imageUrl(hash),
            fit: BoxFit.contain,
            semanticLabel: caption.isEmpty ? null : caption,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _imageGrid(BuildContext context, List<md.Element> images) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 220).floor().clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final image in images)
            SizedBox(width: width, child: _captionedImage(context, image)),
        ],
      );
    });
  }

  Widget _list(BuildContext context, md.Element element) {
    final items = (element.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((e) => e.tag == 'li')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: _richText(context, item)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _table(BuildContext context, md.Element element) {
    final headerCells = <md.Element>[];
    final bodyRows = <List<md.Element>>[];
    for (final section in (element.children ?? const <md.Node>[]).whereType<md.Element>()) {
      for (final row in (section.children ?? const <md.Node>[]).whereType<md.Element>()) {
        final cells = (row.children ?? const <md.Node>[])
            .whereType<md.Element>()
            .where((e) => e.tag == 'th' || e.tag == 'td')
            .toList();
        if (section.tag == 'thead') {
          headerCells.addAll(cells);
        } else {
          bodyRows.add(cells);
        }
      }
    }
    final columns = [
      headerCells.length,
      ...bodyRows.map((r) => r.length),
    ].reduce((a, b) => a > b ? a : b);
    if (columns == 0) return const SizedBox.shrink();

    List<Widget> pad(List<Widget> cells) => [
          ...cells,
          for (var i = cells.length; i < columns; i++)
            const TableCell(child: SizedBox.shrink()),
        ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Theme.of(context).dividerColor),
        children: [
          if (headerCells.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: pad([
                for (final cell in headerCells) _tableCell(context, cell, bold: true),
              ]),
            ),
          for (final row in bodyRows)
            TableRow(
              children: pad([for (final cell in row) _tableCell(context, cell)]),
            ),
        ],
      ),
    );
  }

  Widget _tableCell(BuildContext context, md.Element cell, {bool bold = false}) {
    final images = _inlineImages(cell);
    final Widget content;
    if (images.isNotEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final image in images) SizedBox(width: 160, child: _captionedImage(context, image)),
          if (cell.textContent.trim().isNotEmpty) _richText(context, cell),
        ],
      );
    } else {
      content = bold
          ? Text(cell.textContent, style: const TextStyle(fontWeight: FontWeight.bold))
          : _richText(context, cell);
    }
    return TableCell(
      // Image-bearing cells bottom-align so texts share a baseline (FR-021).
      verticalAlignment: images.isNotEmpty
          ? TableCellVerticalAlignment.bottom
          : TableCellVerticalAlignment.top,
      child: Padding(padding: const EdgeInsets.all(6), child: content),
    );
  }
}
