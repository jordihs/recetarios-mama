import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/recipes/ingredients_editor.dart';
import 'package:recetarios/features/recipes/recipe_view_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/block_editor/block_list_editor.dart';

Recipe _recipe() => Recipe(
      id: 'r1',
      title: 'Tortilla',
      introduction: [],
      ingredients: IngredientsList(groups: [
        IngredientGroup(items: ['Huevos'])
      ]),
      preparation: [
        {
          'type': 'paragraph',
          'spans': [
            {'text': 'Freír.'}
          ],
        }
      ],
    );

Widget _app(Widget child, {Recipe? recipe}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(ApiClient('http://127.0.0.1:9')),
      if (recipe != null) recipeDetailProvider.overrideWith((ref, id) async => recipe),
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
  testWidgets('recipe opens read-only and toggles into edit mode', (tester) async {
    await tester.pumpWidget(_app(const RecipeViewScreen(recipeId: 'r1'), recipe: _recipe()));
    await tester.pumpAndSettle();

    // Read-only: no save/discard buttons, edit toggle present.
    expect(find.text('Guardar'), findsNothing);
    expect(find.byTooltip('Editar'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    // Edit mode: save and discard buttons appear (FR-018).
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Descartar cambios'), findsOneWidget);
  });

  testWidgets('discard returns to view mode without keeping draft edits', (tester) async {
    await tester.pumpWidget(_app(const RecipeViewScreen(recipeId: 'r1'), recipe: _recipe()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    // Modify the title in the draft.
    final titleField = find.widgetWithText(TextFormField, 'Tortilla').first;
    await tester.enterText(titleField, 'Cambiada');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descartar cambios'));
    await tester.pumpAndSettle();

    // Back in view mode with the original title (AppBar shows saved state).
    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Tortilla'), findsWidgets);
    expect(find.text('Cambiada'), findsNothing);
  });

  testWidgets('block editor adds and removes paragraph blocks', (tester) async {
    final blocks = <ContentBlock>[];
    var changed = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: SingleChildScrollView(
        child: BlockListEditor(
          blocks: blocks,
          api: ApiClient('http://127.0.0.1:9'),
          onChanged: () => changed++,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir párrafo'));
    await tester.pumpAndSettle();
    expect(blocks.length, 1);
    expect(blocks.first['type'], 'paragraph');
    expect(changed, greaterThan(0));

    await tester.enterText(find.byType(TextField).first, 'Hola');
    expect((blocks.first['spans'] as List).first['text'], 'Hola');

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(blocks, isEmpty);
  });

  testWidgets('ingredients editor adds groups and items', (tester) async {
    final value = IngredientsList(groups: [IngredientGroup(items: ['Huevos'])]);
    var changed = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: SingleChildScrollView(
        child: IngredientsEditor(value: value, onChanged: () => changed++),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir ingrediente'));
    await tester.pumpAndSettle();
    expect(value.groups.first.items.length, 2);

    await tester.tap(find.text('Añadir grupo'));
    await tester.pumpAndSettle();
    expect(value.groups.length, 2);
    expect(changed, greaterThanOrEqualTo(2));
  });
}
