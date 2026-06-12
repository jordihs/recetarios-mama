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
  testWidgets('image-bearing table cells bottom-align; text cells unchanged',
      (tester) async {
    const markdown = '| Especie | Foto |\n'
        '| --- | --- |\n'
        '| Níscalo con texto | ![Níscalo](image://$_hash) |\n';
    await tester.pumpWidget(_app(markdown));
    await tester.pump();

    final cells =
        tester.widgetList<TableCell>(find.byType(TableCell)).toList();
    expect(cells, isNotEmpty);

    bool hasImage(TableCell cell) => find
        .descendant(of: find.byWidget(cell), matching: find.byType(Image))
        .evaluate()
        .isNotEmpty;

    var imageCells = 0;
    var textCells = 0;
    for (final cell in cells) {
      if (hasImage(cell)) {
        imageCells++;
        expect(cell.verticalAlignment, TableCellVerticalAlignment.bottom,
            reason: 'image cells must bottom-align (FR-021)');
      } else {
        textCells++;
        expect(cell.verticalAlignment, isNot(TableCellVerticalAlignment.bottom),
            reason: 'text-only cells keep the default alignment');
      }
    }
    expect(imageCells, greaterThan(0));
    expect(textCells, greaterThan(0));
    while (tester.takeException() != null) {}
  });
}
