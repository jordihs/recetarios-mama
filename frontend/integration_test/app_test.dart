/// End-to-end journey (T075): launch the real app against a live backend,
/// browse, create a book, and verify the responsive shell.
///
/// Run with a dev backend already up:
///   $env:RECETARIOS_BACKEND_URL = "http://127.0.0.1:8765"
///   flutter test integration_test -d windows
///
/// Requires the Windows desktop toolchain (Visual Studio C++ workload).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:recetarios/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot, browse books, create a book', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Home: the Spanish book list is shown without any login step (FR-002).
    expect(find.text('Recetarios de mamá'), findsOneWidget);

    // Create a book through the form (US1 journey). Save lives in the pinned
    // bottom bar, always visible regardless of the content editor's height.
    await tester.tap(find.text('Añadir libro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Libro e2e');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Libro e2e'), findsOneWidget);

    // Open it: empty chapter state appears with the add-chapter action (US2).
    await tester.tap(find.text('Libro e2e'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir capítulo'), findsOneWidget);
  });
}
