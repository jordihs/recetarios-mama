import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'package:recetarios/data/local/app_database.dart';

class SettingsStore {
  SettingsStore(AppDatabase appDb)
      : _db = appDb.db,
        _dataDir = appDb.dataDir;

  final Database _db;
  final String _dataDir;

  Future<Map<String, String>> getAll() async {
    final rows = await _db.query('settings');
    final map = <String, String>{'pdf_output_dir': _defaultOutputDir()};
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  Future<String?> get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) {
      if (key == 'pdf_output_dir') return _defaultOutputDir();
      return null;
    }
    return rows.first['value'] as String;
  }

  Future<void> update(Map<String, String> values) async {
    final batch = _db.batch();
    for (final entry in values.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  String _defaultOutputDir() {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? _dataDir;
    }
    return Platform.environment['HOME'] ?? _dataDir;
  }
}
