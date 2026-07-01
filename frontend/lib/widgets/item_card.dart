import 'dart:io';

import 'package:flutter/material.dart';

/// Shared card for books, chapters, and recipes: image (optional),
/// title, and description truncated with an ellipsis (FR-006/009/012).
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.title,
    this.description = '',
    this.imageFilePath,
    this.onTap,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String description;
  final String? imageFilePath;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Compact mode renders title-only rows (recipe list toggle, FR-013).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing,
          onTap: onTap,
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageFilePath != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(imageFilePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: imageFilePath != null
                            ? Text(
                                description,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 4,
                              )
                            : LayoutBuilder(builder: (context, constraints) {
                                final style = theme.textTheme.bodySmall;
                                final lineHeight = (style?.fontSize ?? 12) *
                                    (style?.height ?? 1.4);
                                final lines = (constraints.maxHeight / lineHeight)
                                    .floor()
                                    .clamp(4, 40);
                                return Text(
                                  description,
                                  style: style,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: lines,
                                );
                              }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid wrapper used by all list screens (FR-001).
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 280).floor().clamp(1, 6);
        return GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: children,
        );
      },
    );
  }
}
