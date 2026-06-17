import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/widgets/markdown_view.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _app(String markdown) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MarkdownView(
          markdown: markdown,
          api: ApiClient('http://127.0.0.1:9'),
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
    await tester.pumpWidget(_app(markdown));
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
