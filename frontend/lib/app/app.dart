import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:recetarios/app/router.dart';
import 'package:recetarios/features/library_reset/library_reset_gate.dart';
import 'package:recetarios/l10n/app_localizations.dart';

class RecetariosApp extends StatelessWidget {
  RecetariosApp({super.key});

  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Recetarios de mamá',
      routerConfig: _router,
      // Old-format libraries block the whole UI behind the reset flow (FR-014).
      builder: (context, child) =>
          LibraryResetGate(child: child ?? const SizedBox.shrink()),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E63)),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
