import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/widgets/markdown_view.dart';

import '../helpers/test_database.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Future<Widget> _app(String markdown) async {
  final imageStore = await testImageStore();
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MarkdownView(
          markdown: markdown,
          imageStore: imageStore,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('all table cells top-align regardless of content',
      (tester) async {
    const markdown = '| Especie | Foto |\n'
        '| --- | --- |\n'
        '| Níscalo con texto | ![Níscalo](image://$_hash) |\n';
    await tester.pumpWidget(await _app(markdown));
    await tester.pump();

    final cells =
        tester.widgetList<TableCell>(find.byType(TableCell)).toList();
    expect(cells, isNotEmpty);

    for (final cell in cells) {
      expect(cell.verticalAlignment, TableCellVerticalAlignment.top,
          reason: 'all cells must top-align');
    }
    while (tester.takeException() != null) {}
  });
}
