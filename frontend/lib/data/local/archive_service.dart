import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:recetarios/data/local/app_database.dart';
import 'package:recetarios/data/local/image_store.dart';
import 'package:recetarios/data/local/local_repository.dart';

class ArchiveException implements Exception {
  ArchiveException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class ArchiveService {
  ArchiveService(AppDatabase appDb, ImageStore imageStore, LocalRepository repo)
      : _db = appDb.db,
        _imageStore = imageStore,
        _repo = repo;

  final Database _db;
  final ImageStore _imageStore;
  final LocalRepository _repo;

  Future<void> export(String targetPath) async {
    final books = await _exportBooks();
    final manifest = jsonEncode({'format_version': 2, 'books': books});
    final manifestBytes = Uint8List.fromList(utf8.encode(manifest));

    final encoder = ZipFileEncoder();
    encoder.create(targetPath);
    encoder.addArchiveFile(ArchiveFile('library.json', manifestBytes.length, manifestBytes));

    final hashes = _collectImageHashes(books);
    for (final hash in hashes) {
      final path = _imageStore.pathFor(hash);
      if (path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final ext = p.extension(path).replaceFirst('.', '');
      encoder.addArchiveFile(ArchiveFile('images/$hash.$ext', bytes.length, bytes));
    }
    encoder.closeSync();
  }

  Future<void> importReplace(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestFile = archive.findFile('library.json');
    if (manifestFile == null) {
      throw ArchiveException('archive_invalid', 'Archivo sin library.json');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, dynamic>;
    final version = manifest['format_version'] as int? ?? 0;
    if (version != 2) {
      throw ArchiveException(
        'archive_unsupported_version',
        'Versión de archivo no compatible: $version',
      );
    }

    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('images/')) {
        final imageBytes = Uint8List.fromList(file.content as List<int>);
        await _imageStore.ingest(imageBytes);
      }
    }

    await _db.transaction((txn) async {
      await txn.delete('books');
      final booksList = manifest['books'] as List? ?? [];
      await _importBooks(txn, booksList);
    });

    await _repo.rebuildFts();
  }

  // ---------------------------------------------------------------- export helpers

  Future<List<Map<String, dynamic>>> _exportBooks() async {
    final bookRows = await _db.query('books', orderBy: 'position ASC');
    final result = <Map<String, dynamic>>[];
    for (final book in bookRows) {
      final bookId = book['id'] as String;
      final chapters = await _exportChapters(bookId, null);
      result.add({
        'id': bookId,
        'title': book['title'],
        'cover_image': book['cover_image'],
        'presentation': book['presentation'],
        'note': book['note'],
        'position': book['position'],
        'chapters': chapters,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _exportChapters(
      String bookId, String? parentId) async {
    final where = parentId == null
        ? 'book_id = ? AND parent_chapter_id IS NULL'
        : 'book_id = ? AND parent_chapter_id = ?';
    final args = parentId == null ? [bookId] : [bookId, parentId];
    final rows = await _db.query('chapters',
        where: where, whereArgs: args, orderBy: 'position ASC');
    final result = <Map<String, dynamic>>[];
    for (final ch in rows) {
      final chId = ch['id'] as String;
      final subchapters = await _exportChapters(bookId, chId);
      final recipes = await _exportRecipes(chId);
      result.add({
        'id': chId,
        'book_id': ch['book_id'],
        'parent_chapter_id': ch['parent_chapter_id'],
        'title': ch['title'],
        'cover_image': ch['cover_image'],
        'presentation': ch['presentation'],
        'note': ch['note'],
        'position': ch['position'],
        'chapters': subchapters,
        'recipes': recipes,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _exportRecipes(String chapterId) async {
    final rows = await _db.query('recipes',
        where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'position ASC');
    return rows.map((r) => {
          'id': r['id'],
          'chapter_id': r['chapter_id'],
          'title': r['title'],
          'image': r['image'],
          'introduction': r['introduction'],
          'ingredients': r['ingredients'],
          'preparation': r['preparation'],
          'note': r['note'],
          'position': r['position'],
        }).toList();
  }

  Set<String> _collectImageHashes(List<Map<String, dynamic>> books) {
    final hashes = <String>{};
    void addIfHash(dynamic value) {
      if (value is String && value.isNotEmpty) hashes.add(value);
    }
    void processMarkdown(dynamic field) {
      if (field is! String) return;
      for (final m in RegExp(r'image://([0-9a-f]{64})').allMatches(field)) {
        hashes.add(m.group(1)!);
      }
    }
    void processRecipe(Map<String, dynamic> r) {
      addIfHash(r['image']);
      processMarkdown(r['introduction']);
      processMarkdown(r['preparation']);
      processMarkdown(r['note']);
    }
    void processChapter(Map<String, dynamic> ch) {
      addIfHash(ch['cover_image']);
      for (final r in (ch['recipes'] as List? ?? [])) {
        processRecipe((r as Map).cast<String, dynamic>());
      }
      for (final sub in (ch['chapters'] as List? ?? [])) {
        processChapter((sub as Map).cast<String, dynamic>());
      }
    }
    for (final book in books) {
      addIfHash(book['cover_image']);
      for (final ch in (book['chapters'] as List? ?? [])) {
        processChapter((ch as Map).cast<String, dynamic>());
      }
    }
    return hashes;
  }

  // ---------------------------------------------------------------- import helpers

  Future<void> _importBooks(Transaction txn, List books) async {
    for (final bookData in books) {
      final book = (bookData as Map).cast<String, dynamic>();
      await txn.insert('books', {
        'id': book['id'],
        'title': book['title'],
        'cover_image': book['cover_image'],
        'presentation': book['presentation'] ?? '',
        'note': book['note'],
        'position': book['position'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _importChapters(txn, book['chapters'] as List? ?? []);
    }
  }

  Future<void> _importChapters(Transaction txn, List chapters) async {
    for (final chData in chapters) {
      final ch = (chData as Map).cast<String, dynamic>();
      await txn.insert('chapters', {
        'id': ch['id'],
        'book_id': ch['book_id'],
        'parent_chapter_id': ch['parent_chapter_id'],
        'title': ch['title'],
        'cover_image': ch['cover_image'],
        'presentation': ch['presentation'] ?? '',
        'note': ch['note'],
        'position': ch['position'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _importChapters(txn, ch['chapters'] as List? ?? []);
      await _importRecipes(txn, ch['recipes'] as List? ?? []);
    }
  }

  Future<void> _importRecipes(Transaction txn, List recipes) async {
    for (final recData in recipes) {
      final rec = (recData as Map).cast<String, dynamic>();
      final ingredients = rec['ingredients'];
      await txn.insert('recipes', {
        'id': rec['id'],
        'chapter_id': rec['chapter_id'],
        'title': rec['title'],
        'image': rec['image'],
        'introduction': rec['introduction'] ?? '',
        'ingredients': ingredients is String ? ingredients : jsonEncode(ingredients),
        'preparation': rec['preparation'] ?? '',
        'note': rec['note'],
        'position': rec['position'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
