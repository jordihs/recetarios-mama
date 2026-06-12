import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/recipes/recipe_list_section.dart';
import 'package:recetarios/features/recipes/recipe_view_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/item_card.dart';

Widget _app(Widget child, {List<ItemSummary>? recipes, Recipe? recipe}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(ApiClient('http://127.0.0.1:9')),
      if (recipes != null)
        recipeListProvider.overrideWith((ref, chapterId) async => recipes),
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Recipe _recipe() => Recipe(
      id: 'r1',
      title: 'Tortilla',
      introduction: 'INTRO-TEXT con **énfasis**.',
      ingredients: IngredientsList(servings: '4', groups: [
        IngredientGroup(items: ['2 huevos']),
        IngredientGroup(title: 'Para el aliño', items: ['Aceite']),
      ]),
      preparation: 'PREP-TEXT',
      note: 'Una nota',
    );

void main() {
  testWidgets('toggle switches between detailed and titles-only modes', (tester) async {
    final items = [
      ItemSummary(id: 'r1', title: 'Tortilla', description: 'Con cebolla'),
      ItemSummary(id: 'r2', title: 'Gazpacho', description: 'Frío'),
    ];
    await tester.pumpWidget(_app(
      const RecipeListSection(bookId: 'b', chapterId: 'c'),
      recipes: items,
    ));
    await tester.pumpAndSettle();

    // Detailed mode: descriptions visible.
    expect(find.text('Con cebolla'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Titles-only mode: titles remain, descriptions gone, compact cards used.
    expect(find.text('Tortilla'), findsOneWidget);
    expect(find.text('Con cebolla'), findsNothing);
    final compactCards =
        tester.widgetList<ItemCard>(find.byType(ItemCard)).where((c) => c.compact);
    expect(compactCards.length, 2);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Con cebolla'), findsOneWidget);
  });

  testWidgets('recipe view shows introduction, then ingredients, then preparation',
      (tester) async {
    await tester.pumpWidget(_app(
      RecipeContentView(recipe: _recipe()),
      recipe: _recipe(),
    ));
    await tester.pumpAndSettle();

    final introY = tester.getTopLeft(find.textContaining('INTRO-TEXT')).dy;
    final ingredientsY = tester.getTopLeft(find.text('Ingredientes')).dy;
    final prepY = tester.getTopLeft(find.text('Preparación')).dy;
    expect(introY, lessThan(ingredientsY));
    expect(ingredientsY, lessThan(prepY));

    expect(find.text('Para 4 personas'), findsOneWidget);
    expect(find.text('Para el aliño'), findsOneWidget);
    expect(find.textContaining('2 huevos'), findsOneWidget);
    expect(find.text('Una nota'), findsOneWidget);
  });
}
