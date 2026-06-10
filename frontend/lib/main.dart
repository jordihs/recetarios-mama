import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recetarios/app/app.dart';
import 'package:recetarios/app/providers.dart';
import 'package:recetarios/core/backend.dart';
import 'package:recetarios/data/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootSplash());
  try {
    final connection = await BackendConnection.establish();
    final api = ApiClient(connection.baseUrl);
    final lifecycle = _BackendLifecycle(connection);
    runApp(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: _LifecycleScope(lifecycle: lifecycle, child: RecetariosApp()),
      ),
    );
  } catch (_) {
    runApp(const _BootFailure());
  }
}

/// Shuts the backend down when the app window closes.
class _BackendLifecycle {
  _BackendLifecycle(this.connection) {
    _listener = AppLifecycleListener(onExitRequested: () async {
      await connection.dispose();
      return AppExitResponse.exit;
    });
  }

  final BackendConnection connection;
  late final AppLifecycleListener _listener;

  void dispose() => _listener.dispose();
}

class _LifecycleScope extends StatefulWidget {
  const _LifecycleScope({required this.lifecycle, required this.child});

  final _BackendLifecycle lifecycle;
  final Widget child;

  @override
  State<_LifecycleScope> createState() => _LifecycleScopeState();
}

class _LifecycleScopeState extends State<_LifecycleScope> {
  @override
  void dispose() {
    widget.lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  const _BootFailure();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se ha podido iniciar el servicio de datos. Vuelve a abrir la aplicación.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
