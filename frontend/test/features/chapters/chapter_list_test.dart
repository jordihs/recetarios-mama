import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/features/chapters/chapter_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';

Widget _wrap(
  Widget child, {
  required Map<String?, List<ItemSummary>> chaptersByParent,
  String bookPresentation = '',
  String chapterPresentation = '',
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(ApiClient('http://127.0.0.1:9')),
      chapterListProvider.overrideWith(
        (ref, args) async => chaptersByParent[args.parentId] ?? <ItemSummary>[],
      ),
      bookDetailProvider.overrideWith(
        (ref, id) async => BookDetail(
          id: id,
          title: 'Libro $id',
          presentation: bookPresentation,
        ),
      ),
      chapterDetailProvider.overrideWith(
        (ref, id) async => ChapterDetail(
          id: id,
          bookId: 'book-1',
          title: 'Capítulo $id',
          presentation: chapterPresentation,
        ),
      ),
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

void main() {
  testWidgets('book with no chapters shows Spanish empty state', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChapterListScreen(bookId: 'book-1'),
      chaptersByParent: const {},
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('todavía no tiene capítulos'), findsOneWidget);
  });

  testWidgets('top-level chapters render as cards', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChapterListScreen(bookId: 'book-1'),
      chaptersByParent: {
        null: [
          ItemSummary(id: 'c1', title: 'Entrantes', description: 'Para abrir boca'),
          ItemSummary(id: 'c2', title: 'Guisos'),
        ],
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ItemCard), findsNWidgets(2));
    expect(find.text('Entrantes'), findsOneWidget);
    expect(find.text('Para abrir boca'), findsOneWidget);
  });

  testWidgets('nested level lists subchapters of the chapter', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChapterListScreen(bookId: 'book-1', chapterId: 'c1'),
      chaptersByParent: {
        'c1': [ItemSummary(id: 'c1-1', title: 'Preparación')],
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('Subcapítulos'), findsOneWidget);
    expect(find.text('Preparación'), findsOneWidget);
  });

  testWidgets('book introduction is shown in full above its chapters', (tester) async {
    const intro = 'Primer párrafo de la introducción del libro.\n\n'
        'Segundo párrafo completo, sin recortar.\n';
    await tester.pumpWidget(_wrap(
      const ChapterListScreen(bookId: 'book-1'),
      chaptersByParent: {
        null: [ItemSummary(id: 'c1', title: 'Entrantes')],
      },
      bookPresentation: intro,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Primer párrafo de la introducción del libro.'), findsOneWidget);
    expect(find.textContaining('Segundo párrafo completo, sin recortar.'), findsOneWidget);
    // Edit button for the parent book is available from the full view.
    expect(find.byTooltip('Editar libro'), findsOneWidget);
  });

  testWidgets('chapter introduction is shown in full above its content', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChapterListScreen(bookId: 'book-1', chapterId: 'c1'),
      chaptersByParent: const {},
      chapterPresentation: 'Introducción completa del capítulo.',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Introducción completa del capítulo.'), findsOneWidget);
    expect(find.byTooltip('Editar capítulo'), findsOneWidget);
  });
}
