import 'package:appflowy_editor/appflowy_editor.dart'
    show AppFlowyEditorL10n, AppFlowyEditorLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/app.dart';
import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/local/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootSplash());
  AppFlowyEditorL10n.current =
      await AppFlowyEditorLocalizations.load(const Locale('es', 'VE'));
  try {
    final db = await AppDatabase.open();
    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: RecetariosApp(),
      ),
    );
  } catch (e) {
    runApp(_BootFailure(error: '$e'));
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Iniciando la aplicación…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se ha podido abrir la base de datos.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
