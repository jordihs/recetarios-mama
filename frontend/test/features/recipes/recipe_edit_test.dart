import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/recipes/ingredients_editor.dart';
import 'package:recetarios/features/recipes/recipe_view_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor.dart';

import '../../helpers/test_database.dart';

Recipe _recipe() => Recipe(
      id: 'r1',
      title: 'Tortilla',
      introduction: '',
      ingredients: IngredientsList(groups: [
        IngredientGroup(items: ['Huevos'])
      ]),
      preparation: 'Freír.',
    );

Future<Widget> _app(Widget child, {Recipe? recipe}) async {
  final imageStore = await testImageStore();
  return ProviderScope(
    overrides: [
      imageStoreProvider.overrideWithValue(imageStore),
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
    await tester.pumpWidget(await _app(const RecipeViewScreen(recipeId: 'r1'), recipe: _recipe()));
    await tester.pumpAndSettle();

    expect(find.text('Guardar'), findsNothing);
    expect(find.byTooltip('Editar'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Descartar cambios'), findsOneWidget);
  });

  testWidgets('discard returns to view mode without keeping draft edits', (tester) async {
    await tester.pumpWidget(await _app(const RecipeViewScreen(recipeId: 'r1'), recipe: _recipe()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    final titleField = find.widgetWithText(TextFormField, 'Tortilla').first;
    await tester.enterText(titleField, 'Cambiada');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descartar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Tortilla'), findsWidgets);
    expect(find.text('Cambiada'), findsNothing);
  });

  testWidgets('edit mode uses one rich editor per section', (tester) async {
    final recipe = _recipe();
    await tester.pumpWidget(await _app(const RecipeViewScreen(recipeId: 'r1'), recipe: recipe));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Añadir párrafo'), findsNothing);
    expect(find.byType(MarkdownEditor), findsNWidgets(2));
    expect(find.textContaining('Freír', findRichText: true), findsWidgets);

    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Descartar cambios'), findsOneWidget);
  });

  testWidgets('ingredients editor adds groups and items', (tester) async {
    final value = IngredientsList(groups: [IngredientGroup(items: ['Huevos'])]);
    var changed = 0;
    final imageStore = await testImageStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [imageStoreProvider.overrideWithValue(imageStore)],
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: IngredientsEditor(value: value, onChanged: () => changed++),
          ),
        ),
      ),
    ));
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
