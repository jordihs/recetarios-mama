import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'package:recetarios/data/local/app_database.dart';
import 'package:recetarios/data/models.dart';

String _uuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String h(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${h(bytes[0])}${h(bytes[1])}${h(bytes[2])}${h(bytes[3])}-'
      '${h(bytes[4])}${h(bytes[5])}-'
      '${h(bytes[6])}${h(bytes[7])}-'
      '${h(bytes[8])}${h(bytes[9])}-'
      '${h(bytes[10])}${h(bytes[11])}${h(bytes[12])}${h(bytes[13])}${h(bytes[14])}${h(bytes[15])}';
}

String _plainText(String markdown) => markdown
    .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
    .replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), '')
    .replaceAll(RegExp(r'[#*_`>|~]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class LocalRepository {
  LocalRepository(AppDatabase appDb) : _db = appDb.db;

  final Database _db;

  // ----------------------------------------------------------------- books

  Future<List<ItemSummary>> listBooks() async {
    final rows = await _db.query('books', orderBy: 'position ASC, rowid ASC');
    return rows.map(_bookSummary).toList();
  }

  Future<BookDetail> getBook(String id) async {
    final rows = await _db.query('books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Book not found: $id');
    return _bookDetail(rows.first);
  }

  Future<BookDetail> createBook({
    required String title,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    final id = _uuid();
    final pos = await _nextPosition('books', null, null);
    await _db.insert('books', {
      'id': id,
      'title': title,
      'cover_image': coverImage,
      'presentation': presentation,
      'note': note,
      'position': pos,
    });
    return getBook(id);
  }

  Future<BookDetail> updateBook(
    String id, {
    required String title,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    await _db.update(
      'books',
      {'title': title, 'cover_image': coverImage, 'presentation': presentation, 'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
    return getBook(id);
  }

  Future<void> deleteBook(String id) =>
      _db.delete('books', where: 'id = ?', whereArgs: [id]);

  Future<void> reorderBooks(List<String> ids) async {
    final batch = _db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update('books', {'position': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await batch.commit(noResult: true);
  }

  // --------------------------------------------------------------- chapters

  Future<List<ItemSummary>> listChapters(String bookId, {String? parentChapterId}) async {
    final String where;
    final List<Object?> args;
    if (parentChapterId == null) {
      where = 'book_id = ? AND parent_chapter_id IS NULL';
      args = [bookId];
    } else {
      where = 'book_id = ? AND parent_chapter_id = ?';
      args = [bookId, parentChapterId];
    }
    final rows = await _db.query('chapters',
        where: where, whereArgs: args, orderBy: 'position ASC, rowid ASC');
    return rows.map(_chapterSummary).toList();
  }

  Future<ChapterDetail> getChapter(String id) async {
    final rows = await _db.query('chapters', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Chapter not found: $id');
    return _chapterDetail(rows.first);
  }

  Future<ChapterDetail> createChapter(
    String bookId, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    final id = _uuid();
    final pos = await _nextPosition('chapters', 'book_id = ?', [bookId]);
    await _db.insert('chapters', {
      'id': id,
      'book_id': bookId,
      'parent_chapter_id': parentChapterId,
      'title': title,
      'cover_image': coverImage,
      'presentation': presentation,
      'note': note,
      'position': pos,
    });
    return getChapter(id);
  }

  Future<ChapterDetail> updateChapter(
    String id, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    await _db.update(
      'chapters',
      {
        'title': title,
        'parent_chapter_id': parentChapterId,
        'cover_image': coverImage,
        'presentation': presentation,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return getChapter(id);
  }

  Future<void> deleteChapter(String id) =>
      _db.delete('chapters', where: 'id = ?', whereArgs: [id]);

  Future<void> setChapterCover(String id, String hash) =>
      _db.update('chapters', {'cover_image': hash}, where: 'id = ?', whereArgs: [id]);

  Future<void> setBookCover(String id, String hash) =>
      _db.update('books', {'cover_image': hash}, where: 'id = ?', whereArgs: [id]);

  Future<void> reorderChapters(String bookId, String? parentChapterId, List<String> ids) async {
    final batch = _db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update('chapters', {'position': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ----------------------------------------------------------------- recipes

  Future<List<ItemSummary>> listRecipes(String chapterId) async {
    final rows = await _db.query('recipes',
        where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'position ASC, rowid ASC');
    return rows.map(_recipeSummary).toList();
  }

  Future<Recipe> getRecipe(String id) async {
    final rows = await _db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Recipe not found: $id');
    return _recipeDetail(rows.first);
  }

  Future<Recipe> createRecipe(String chapterId, Map<String, dynamic> body) async {
    final id = _uuid();
    final pos = await _nextPosition('recipes', 'chapter_id = ?', [chapterId]);
    await _db.insert('recipes', {
      'id': id,
      'chapter_id': chapterId,
      'title': body['title'] as String? ?? '',
      'image': body['image'],
      'introduction': body['introduction'] as String? ?? '',
      'ingredients': jsonEncode(body['ingredients'] ?? {'servings': null, 'groups': []}),
      'preparation': body['preparation'] as String? ?? '',
      'note': body['note'],
      'position': pos,
    });
    final recipe = await getRecipe(id);
    await _ftsUpsert(recipe);
    return recipe;
  }

  Future<Recipe> updateRecipe(String id, Map<String, dynamic> body) async {
    final updates = <String, dynamic>{};
    if (body.containsKey('title')) updates['title'] = body['title'];
    if (body.containsKey('image')) updates['image'] = body['image'];
    if (body.containsKey('introduction')) updates['introduction'] = body['introduction'];
    if (body.containsKey('ingredients')) {
      final ing = body['ingredients'];
      updates['ingredients'] = ing is String ? ing : jsonEncode(ing);
    }
    if (body.containsKey('preparation')) updates['preparation'] = body['preparation'];
    if (body.containsKey('note')) updates['note'] = body['note'];
    if (updates.isNotEmpty) {
      await _db.update('recipes', updates, where: 'id = ?', whereArgs: [id]);
    }
    final recipe = await getRecipe(id);
    await _ftsUpsert(recipe);
    return recipe;
  }

  Future<void> deleteRecipe(String id) async {
    await _db.rawDelete(
      'DELETE FROM recipe_fts WHERE rowid = (SELECT rowid FROM recipes WHERE id = ?)',
      [id],
    );
    await _db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderRecipes(String chapterId, List<String> ids) async {
    final batch = _db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update('recipes', {'position': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ----------------------------------------------------------------- search

  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final escaped = query.trim().replaceAll('"', '""');
    final rows = await _db.rawQuery(
      '''
      SELECT r.id AS recipe_id, r.title,
             c.id AS chapter_id, c.title AS chapter_title, c.book_id,
             b.title AS book_title,
             snippet(recipe_fts, 1, '<b>', '</b>', '…', 20) AS snippet
      FROM recipe_fts
      JOIN recipes r ON r.rowid = recipe_fts.rowid
      JOIN chapters c ON c.id = r.chapter_id
      JOIN books b ON b.id = c.book_id
      WHERE recipe_fts MATCH ?
      ORDER BY rank
      LIMIT 50
      ''',
      ['"$escaped"'],
    );
    return rows.map((row) => SearchResult(
          recipeId: row['recipe_id'] as String,
          title: row['title'] as String,
          breadcrumb: [
            {'id': row['book_id'], 'title': row['book_title'], 'type': 'book'},
            {'id': row['chapter_id'], 'title': row['chapter_title'], 'type': 'chapter'},
          ],
          snippet: row['snippet'] as String? ?? '',
        )).toList();
  }

  Future<void> rebuildFts() async {
    await _db.execute('DELETE FROM recipe_fts');
    await _db.execute(
      'INSERT INTO recipe_fts(rowid, title, introduction, preparation, note) '
      'SELECT rowid, title, introduction, preparation, note FROM recipes',
    );
  }

  // ------------------------------------------------------- FTS maintenance

  Future<void> _ftsUpsert(Recipe recipe) async {
    final rows = await _db.query('recipes',
        columns: ['rowid'], where: 'id = ?', whereArgs: [recipe.id]);
    if (rows.isEmpty) return;
    final rowid = rows.first['rowid'] as int;
    await _db.rawDelete('DELETE FROM recipe_fts WHERE rowid = ?', [rowid]);
    await _db.rawInsert(
      'INSERT INTO recipe_fts(rowid, title, introduction, preparation, note) VALUES (?,?,?,?,?)',
      [
        rowid,
        _plainText(recipe.title),
        _plainText(recipe.introduction),
        _plainText(recipe.preparation),
        _plainText(recipe.note ?? ''),
      ],
    );
  }

  // ------------------------------------------------------- mapping helpers

  ItemSummary _bookSummary(Map<String, dynamic> r) => ItemSummary(
        id: r['id'] as String,
        title: r['title'] as String,
        image: r['cover_image'] as String?,
      );

  BookDetail _bookDetail(Map<String, dynamic> r) => BookDetail(
        id: r['id'] as String,
        title: r['title'] as String,
        coverImage: r['cover_image'] as String?,
        presentation: r['presentation'] as String? ?? '',
        note: r['note'] as String?,
      );

  ItemSummary _chapterSummary(Map<String, dynamic> r) => ItemSummary(
        id: r['id'] as String,
        title: r['title'] as String,
        image: r['cover_image'] as String?,
      );

  ChapterDetail _chapterDetail(Map<String, dynamic> r) => ChapterDetail(
        id: r['id'] as String,
        bookId: r['book_id'] as String,
        parentChapterId: r['parent_chapter_id'] as String?,
        title: r['title'] as String,
        coverImage: r['cover_image'] as String?,
        presentation: r['presentation'] as String? ?? '',
        note: r['note'] as String?,
      );

  ItemSummary _recipeSummary(Map<String, dynamic> r) => ItemSummary(
        id: r['id'] as String,
        title: r['title'] as String,
        image: r['image'] as String?,
      );

  Recipe _recipeDetail(Map<String, dynamic> r) {
    final ingJson = r['ingredients'] as String? ?? '{"servings":null,"groups":[]}';
    return Recipe(
      id: r['id'] as String,
      title: r['title'] as String,
      image: r['image'] as String?,
      introduction: r['introduction'] as String? ?? '',
      ingredients: IngredientsList.fromJson(
          jsonDecode(ingJson) as Map<String, dynamic>),
      preparation: r['preparation'] as String? ?? '',
      note: r['note'] as String?,
    );
  }

  // ---------------------------------------------------------------- helpers

  Future<int> _nextPosition(String table, String? where, List<Object?>? args) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM $table'
      '${where != null ? ' WHERE $where' : ''}',
      args,
    );
    return (result.first['next'] as int?) ?? 0;
  }
}
