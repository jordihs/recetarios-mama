import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_form_screen.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';

import '../../helpers/test_database.dart';

Future<Widget> _wrap(Widget child, {List<ItemSummary>? books}) async {
  final imageStore = await testImageStore();
  return ProviderScope(
    overrides: [
      imageStoreProvider.overrideWithValue(imageStore),
      if (books != null) bookListProvider.overrideWith((ref) async => books),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

List<ItemSummary> _books(int count, {String description = ''}) => [
      for (var i = 0; i < count; i++)
        ItemSummary(id: 'book-$i', title: 'Libro $i', description: description),
    ];

void main() {
  testWidgets('book card truncates long descriptions with ellipsis', (tester) async {
    final longDescription = 'Una descripción larguísima. ' * 30;
    await tester.pumpWidget(await _wrap(
      const BookListScreen(),
      books: _books(1, description: longDescription),
    ));
    await tester.pumpAndSettle();

    final descriptionText = tester
        .widgetList<Text>(find.descendant(of: find.byType(ItemCard), matching: find.byType(Text)))
        .firstWhere((t) => (t.data ?? '').startsWith('Una descripción'));
    expect(descriptionText.overflow, TextOverflow.ellipsis);
    expect(descriptionText.maxLines, isNotNull);
  });

  testWidgets('grid adapts column count to viewport width', (tester) async {
    Future<int> columnsAt(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(await _wrap(const BookListScreen(), books: _books(8)));
      await tester.pumpAndSettle();
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    final narrow = await columnsAt(360);
    final wide = await columnsAt(1400);
    expect(narrow, 1);
    expect(wide, greaterThanOrEqualTo(4));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('empty library shows Spanish empty state', (tester) async {
    await tester.pumpWidget(await _wrap(const BookListScreen(), books: <ItemSummary>[]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no hay libros'), findsOneWidget);
  });

  testWidgets('imageless card shows at least double the description lines',
      (tester) async {
    final longDescription = 'Una descripción larguísima que sigue y sigue. ' * 20;
    await tester.pumpWidget(await _wrap(
      const BookListScreen(),
      books: [
        ItemSummary(
          id: 'b1',
          title: 'Con imagen',
          description: longDescription,
          image: 'a' * 64,
        ),
        ItemSummary(id: 'b2', title: 'Sin imagen', description: longDescription),
      ],
    ));
    await tester.pumpAndSettle();

    int descriptionMaxLines(String title) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(ItemCard),
      );
      final text = tester
          .widgetList<Text>(
              find.descendant(of: card, matching: find.byType(Text)))
          .firstWhere((t) => (t.data ?? '').startsWith('Una descripción'));
      return text.maxLines!;
    }

    final withImage = descriptionMaxLines('Con imagen');
    final imageless = descriptionMaxLines('Sin imagen');
    expect(imageless, greaterThanOrEqualTo(2 * withImage),
        reason: 'imageless: $imageless, with image: $withImage');
    expect(withImage, 4);
  });

  testWidgets('book form requires a title', (tester) async {
    await tester.pumpWidget(await _wrap(const BookFormScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El título es obligatorio'), findsOneWidget);
  });
}
