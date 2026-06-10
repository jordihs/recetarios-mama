import 'package:flutter/material.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';

/// Read-only renderer for the 5 content block types
/// (heading, paragraph, image, image_group, table).
class BlockRenderer extends StatelessWidget {
  const BlockRenderer({super.key, required this.blocks, required this.api});

  final List<ContentBlock> blocks;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      // A right-placed image floats beside the following paragraph (legacy layout).
      if (block['type'] == 'image' && block['placement'] == 'right' && i + 1 < blocks.length) {
        final next = blocks[i + 1];
        if (next['type'] == 'paragraph') {
          children.add(_rightImageWithText(context, block, next));
          i++;
          continue;
        }
      }
      children.add(_renderBlock(context, block));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child),
      ],
    );
  }

  Widget _rightImageWithText(BuildContext context, ContentBlock image, ContentBlock paragraph) {
    return LayoutBuilder(builder: (context, constraints) {
      final imageWidth = (constraints.maxWidth * 0.35).clamp(120.0, 320.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _paragraph(context, paragraph)),
          const SizedBox(width: 12),
          SizedBox(width: imageWidth, child: _captionedImage(context, image)),
        ],
      );
    });
  }

  Widget _renderBlock(BuildContext context, ContentBlock block) {
    switch (block['type']) {
      case 'heading':
        return Text(block['text'] as String? ?? '',
            style: Theme.of(context).textTheme.titleLarge);
      case 'paragraph':
        return _paragraph(context, block);
      case 'image':
        return _captionedImage(context, block);
      case 'image_group':
        return _imageGroup(context, block);
      case 'table':
        return _table(context, block);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _paragraph(BuildContext context, ContentBlock block) {
    final spans = (block['spans'] as List? ?? const [])
        .map((s) => (s as Map).cast<String, dynamic>())
        .map((s) => TextSpan(
              text: s['text'] as String? ?? '',
              style: TextStyle(
                fontWeight: (s['bold'] as bool? ?? false) ? FontWeight.bold : null,
                fontStyle: (s['italic'] as bool? ?? false) ? FontStyle.italic : null,
              ),
            ))
        .toList();
    return Text.rich(TextSpan(children: spans), style: Theme.of(context).textTheme.bodyMedium);
  }

  Widget _captionedImage(BuildContext context, Map<String, dynamic> data) {
    final hash = data['image'] as String?;
    if (hash == null) return const SizedBox.shrink();
    final caption = data['caption'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            api.imageUrl(hash),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)),
          ),
        ),
        if (caption != null && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _imageGroup(BuildContext context, ContentBlock block) {
    final images = (block['images'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    if (images.isEmpty) return const SizedBox.shrink();
    final isRow = block['layout'] == 'row';
    return LayoutBuilder(builder: (context, constraints) {
      final columns = isRow ? images.length : (constraints.maxWidth / 220).floor().clamp(1, 4);
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

  Widget _table(BuildContext context, ContentBlock block) {
    final title = block['title'] as String?;
    final header = _cells(block['header']);
    final rows = (block['rows'] as List? ?? const []).map(_cells).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: Theme.of(context).dividerColor),
            children: [
              if (header.isNotEmpty)
                TableRow(
                  decoration:
                      BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  children: [for (final cell in header) _tableCell(context, cell, bold: true)],
                ),
              for (final row in rows)
                TableRow(children: [for (final cell in row) _tableCell(context, cell)]),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _cells(dynamic value) =>
      (value as List? ?? const []).map((c) => (c as Map).cast<String, dynamic>()).toList();

  Widget _tableCell(BuildContext context, Map<String, dynamic> cell, {bool bold = false}) {
    final imageHash = cell['image'] as String?;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: imageHash != null
          ? SizedBox(width: 160, child: _captionedImage(context, {'image': imageHash, 'caption': cell['text']}))
          : Text(
              cell['text'] as String? ?? '',
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
    );
  }
}
