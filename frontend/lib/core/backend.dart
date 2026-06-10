import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves or launches the local Python backend and exposes its base URL.
///
/// Resolution order:
///  1. `RECETARIOS_BACKEND_URL` env var: attach to an already-running backend.
///  2. `RECETARIOS_BACKEND_CMD` env var: spawn that command (dev mode).
///  3. Packaged layout: `<exe-dir>/backend/recetarios.exe` (Windows/Linux).
class BackendConnection {
  BackendConnection._(this.baseUrl, this._process);

  final String baseUrl;
  final Process? _process;

  static Future<BackendConnection> establish() async {
    final env = Platform.environment;
    final externalUrl = env['RECETARIOS_BACKEND_URL'];
    if (externalUrl != null && externalUrl.isNotEmpty) {
      final url = externalUrl.replaceAll(RegExp(r'/+$'), '');
      await _waitHealthy(url);
      return BackendConnection._(url, null);
    }

    final List<String> command;
    final devCmd = env['RECETARIOS_BACKEND_CMD'];
    if (devCmd != null && devCmd.isNotEmpty) {
      command = devCmd.split(' ').where((p) => p.isNotEmpty).toList();
    } else {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bundled = Platform.isWindows
          ? '$exeDir\\backend\\recetarios.exe'
          : '$exeDir/backend/recetarios';
      command = [bundled];
    }

    final process = await Process.start(
      command.first,
      [...command.skip(1), '--port', '0', '--parent-pid', '$pid'],
      mode: ProcessStartMode.normal,
    );

    final port = await _readPortHandshake(process);
    final url = 'http://127.0.0.1:$port';
    await _waitHealthy(url);
    return BackendConnection._(url, process);
  }

  static Future<int> _readPortHandshake(Process process) {
    final completer = Completer<int>();
    final sub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = RegExp(r'^RECETARIOS_PORT=(\d+)$').firstMatch(line.trim());
      if (match != null && !completer.isCompleted) {
        completer.complete(int.parse(match.group(1)!));
      }
    });
    process.exitCode.then((code) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('backend exited with code $code'));
      }
    });
    return completer.future.timeout(const Duration(seconds: 30)).whenComplete(sub.cancel);
  }

  static Future<void> _waitHealthy(String baseUrl) async {
    final client = HttpClient();
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (true) {
        try {
          final request = await client.getUrl(Uri.parse('$baseUrl/health'));
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == 200) return;
        } on IOException {
          // Not up yet.
        }
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('backend /health never became ready');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Graceful stop: ask the backend to exit, then make sure the process dies.
  Future<void> dispose() async {
    final process = _process;
    if (process == null) return;
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$baseUrl/shutdown'));
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
    } on IOException {
      // Backend already gone.
    }
    Future<void>.delayed(const Duration(seconds: 2), () => process.kill());
  }
}
