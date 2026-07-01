import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.db, this.dataDir);

  final Database db;
  final String dataDir;

  static Future<AppDatabase> open() async {
    final dir = await _resolveDataDir();
    await Directory(dir).create(recursive: true);
    await Directory(p.join(dir, 'images')).create(recursive: true);

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = p.join(dir, 'recetarios.db');
    final database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createSchema,
    );
    return AppDatabase._(database, dir);
  }

  static Future<String> _resolveDataDir() async {
    if (!kIsWeb && Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        return p.join(local, 'recetarios-mama');
      }
    }
    if (!kIsWeb && Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return p.join(xdg, 'recetarios-mama');
      }
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, '.local', 'share', 'recetarios-mama');
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'recetarios-mama');
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cover_image TEXT,
        presentation TEXT NOT NULL DEFAULT '',
        note TEXT,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        parent_chapter_id TEXT REFERENCES chapters(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        cover_image TEXT,
        presentation TEXT NOT NULL DEFAULT '',
        note TEXT,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        image TEXT,
        introduction TEXT NOT NULL DEFAULT '',
        ingredients TEXT NOT NULL DEFAULT '{"servings":null,"groups":[]}',
        preparation TEXT NOT NULL DEFAULT '',
        note TEXT,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS images (
        hash TEXT PRIMARY KEY,
        ext TEXT NOT NULL,
        width INTEGER,
        height INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS recipe_fts
        USING fts5(title, introduction, preparation, note,
                   content=recipes, content_rowid=rowid)
    ''');
  }

  /// Creates an isolated in-memory database for use in widget/unit tests.
  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final database = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _createSchema,
    );
    return AppDatabase._(database, Directory.systemTemp.path);
  }

  Future<void> close() => db.close();
}
