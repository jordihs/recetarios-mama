import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/features/library_reset/library_reset_gate.dart';
import 'package:recetarios/l10n/app_localizations.dart';

Widget _app(String format) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(ApiClient('http://127.0.0.1:9')),
      libraryStatusProvider.overrideWith((ref) async => format),
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
      home: const LibraryResetGate(child: Text('APP-CONTENT')),
    ),
  );
}

void main() {
  testWidgets('current library passes straight through', (tester) async {
    await tester.pumpWidget(_app('current'));
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsOneWidget);
  });

  testWidgets('legacy library blocks the UI behind the Spanish reset flow',
      (tester) async {
    await tester.pumpWidget(_app('legacy'));
    await tester.pumpAndSettle();

    // The app content is unreachable (FR-014).
    expect(find.text('APP-CONTENT'), findsNothing);
    expect(find.text('Biblioteca de una versión anterior'), findsOneWidget);
    expect(find.textContaining('versión anterior'), findsWidgets);

    // The reset asks for explicit confirmation first.
    await tester.tap(find.text('Reiniciar biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('¿Reiniciar la biblioteca?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    // Cancelling keeps the gate up and triggers no reset call.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca de una versión anterior'), findsOneWidget);
  });
}
