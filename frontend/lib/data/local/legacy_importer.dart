import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:recetarios/data/local/image_store.dart';
import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/models.dart';

class LegacyImportException implements Exception {
  LegacyImportException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class LegacyImportReport {
  LegacyImportReport({
    required this.bookTitle,
    required this.chapters,
    required this.recipes,
    required this.imagesImported,
    required this.imagesMissing,
  });
  final String bookTitle;
  final int chapters;
  final int recipes;
  final int imagesImported;
  final List<String> imagesMissing;
}

class LegacyImporter {
  LegacyImporter(this._repo, this._imageStore);

  final LocalRepository _repo;
  final ImageStore _imageStore;

  Map<String, dynamic> _loadDocument(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw LegacyImportException('legacy_file_not_found', 'Archivo no encontrado: $path');
    }
    dynamic data;
    try {
      data = jsonDecode(file.readAsStringSync(encoding: utf8));
    } catch (_) {
      throw LegacyImportException('legacy_invalid_format', 'El archivo no es JSON válido');
    }
    if (data is! Map) {
      throw LegacyImportException('legacy_invalid_format', 'Formato inválido');
    }
    final recetario = data['RECETARIO'];
    if (recetario is! Map || _cleanText(recetario['TITULO']).isEmpty) {
      throw LegacyImportException('legacy_invalid_format', 'Falta el nodo RECETARIO o TITULO');
    }
    return recetario.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> inspect(String path) async {
    final doc = _loadDocument(path);
    final title = _cleanText(doc['TITULO']);
    final books = await _repo.listBooks();
    final collision = books.any((b) => b.title == title);
    return {'book_title': title, 'collision': collision};
  }

  Future<LegacyImportReport> run(String path, String onCollision) async {
    final doc = _loadDocument(path);
    final baseDir = File(path).parent.path;
    final title = _cleanText(doc['TITULO']);

    if (onCollision == 'replace') {
      final books = await _repo.listBooks();
      for (final b in books) {
        if (b.title == title) await _repo.deleteBook(b.id);
      }
    }

    final resolver = _ImageResolver(baseDir, _imageStore);

    final intro = await _mapIntroduccion(doc['INTRODUCCION'], resolver);
    final book = await _repo.createBook(
      title: title,
      presentation: intro.markdown,
      note: intro.note,
    );

    var chapterCount = 0;
    var recipeCount = 0;

    try {
      final (ch, rec) = await _importChapters(book.id, null, doc['CAPITULO'], resolver);
      chapterCount += ch;
      recipeCount += rec;

      final rootRecipes = _asList(doc['RECETA']);
      if (rootRecipes.isNotEmpty) {
        final rootCh = await _repo.createChapter(book.id, title: title);
        chapterCount++;
        recipeCount += await _importRecipes(rootCh.id, rootRecipes, resolver);
      }
    } catch (_) {
      await _repo.deleteBook(book.id);
      rethrow;
    }

    await _assignFallbackImages(book.id);

    return LegacyImportReport(
      bookTitle: title,
      chapters: chapterCount,
      recipes: recipeCount,
      imagesImported: resolver.imported,
      imagesMissing: resolver.missing,
    );
  }

  // ---------------------------------------------------------------- chapters/recipes

  Future<(int chapters, int recipes)> _importChapters(
    String bookId,
    String? parentId,
    dynamic chaptersNode,
    _ImageResolver resolver,
  ) async {
    var chapters = 0;
    var recipes = 0;
    for (final chapter in _asList(chaptersNode)) {
      final ch = (chapter as Map?)?.cast<String, dynamic>() ?? {};
      final attrs = (ch['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};
      final name = _cleanText(attrs['nombre']).isEmpty
          ? '(capítulo)'
          : _cleanText(attrs['nombre']);
      final intro = await _mapIntroduccion(ch['INTRODUCCION'], resolver);
      final chObj = await _repo.createChapter(
        bookId,
        parentChapterId: parentId,
        title: name,
        presentation: intro.markdown,
        note: intro.note,
      );
      chapters++;
      recipes += await _importRecipes(chObj.id, _asList(ch['RECETA']), resolver);
      final (subCh, subRec) =
          await _importChapters(bookId, chObj.id, ch['CAPITULO'], resolver);
      chapters += subCh;
      recipes += subRec;
    }
    return (chapters, recipes);
  }

  Future<int> _importRecipes(
      String chapterId, List<dynamic> recipes, _ImageResolver resolver) async {
    var count = 0;
    for (final raw in recipes) {
      final legacy = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final attrs = (legacy['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};

      final imageSrc = _cleanText(attrs['imagen'] as String? ?? '');
      final imageHash = imageSrc.isNotEmpty ? await resolver.resolve(imageSrc) : null;

      final ingNode = (legacy['INGREDIENTES'] as Map?)?.cast<String, dynamic>() ?? {};
      final ingAttrs = (ingNode['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};
      final servings = _cleanText(ingAttrs['personas'] as String? ?? '').let(
          (s) => s.isEmpty ? null : s);
      final groups = <IngredientGroup>[];
      for (final g in _asList(ingNode['GRUPO'])) {
        final gMap = (g as Map?)?.cast<String, dynamic>() ?? {};
        final gAttrs = (gMap['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};
        final gTitle =
            _cleanText(gAttrs['titulo'] as String? ?? '').let((s) => s.isEmpty ? null : s);
        final items = _asList(gMap['INGREDIENTE'])
            .map(_cleanText)
            .where((s) => s.isNotEmpty)
            .toList();
        groups.add(IngredientGroup(title: gTitle, items: items));
      }

      final preparation = _asList(legacy['PREPARACION'])
          .map(_cleanText)
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      final noteRaw = legacy['NOTA'] ?? legacy['nota'];
      final note =
          _asList(noteRaw).map(_cleanText).where((s) => s.isNotEmpty).join('\n\n');

      await _repo.createRecipe(chapterId, {
        'title': _cleanText(legacy['TITULO']).let((s) => s.isEmpty ? '(sin título)' : s),
        'image': imageHash,
        'introduction': '',
        'ingredients': IngredientsList(servings: servings, groups: groups).toJson(),
        'preparation': preparation,
        'note': note.isEmpty ? null : note,
      });
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------- intro mapper

  Future<({String markdown, String? note})> _mapIntroduccion(
      dynamic introNode, _ImageResolver resolver) async {
    final intro = (introNode as Map?)?.cast<String, dynamic>() ?? {};
    final blocks = <String>[];
    final notes = <String>[];
    var firstTitle = true;

    for (final element in _asList(intro['CONTENIDO'])) {
      final el = (element as Map?)?.cast<String, dynamic>();
      if (el == null) continue;
      switch (el['tipo'] as String?) {
        case 'TITULO':
          final text = _cleanText(el['texto']);
          if (text.isNotEmpty) {
            blocks.add((firstTitle ? '## ' : '### ') + text);
            firstTitle = false;
          }
        case 'PARRAFO':
          final text = _cleanText(el['texto']);
          if (text.isNotEmpty) blocks.add(text);
        case 'IMAGEN':
          final line = await _imageLine(el['imagen'], resolver);
          if (line != null) blocks.add(line);
        case 'IMAGENES':
          final lines = <String>[];
          for (final img in _asList(el['imagenes'])) {
            final line = await _imageLine(img, resolver);
            if (line != null) lines.add(line);
          }
          if (lines.isNotEmpty) blocks.add(lines.join('\n'));
        case 'TABLA':
          final table = _tableMarkdown(el['tabla']);
          if (table.isNotEmpty) blocks.add(table);
        case 'NOTA':
          final text = _cleanText(el['texto']);
          if (text.isNotEmpty) notes.add(text);
      }
    }
    return (
      markdown: blocks.join('\n\n'),
      note: notes.isEmpty ? null : notes.join('\n\n'),
    );
  }

  Future<String?> _imageLine(dynamic imgNode, _ImageResolver resolver) async {
    final img = (imgNode as Map?)?.cast<String, dynamic>() ?? {};
    final attrs = (img['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final src = _cleanText(attrs['src'] as String? ?? '');
    if (src.isEmpty) return null;
    final hash = await resolver.resolve(src);
    if (hash == null) return null;
    final caption = _cleanText(img['#text'] as String? ?? '');
    return '![$caption](image://$hash)';
  }

  String _tableMarkdown(dynamic tableNode) {
    final table = (tableNode as Map?)?.cast<String, dynamic>() ?? {};
    final attrs = (table['@attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final header = _asList((table['CABECERA'] as Map?)?['CELDA']);
    final rows = _asList(table['FILA']).map((r) => _asList((r as Map?)?['CELDA'])).toList();
    final columns = [header.length, ...rows.map((r) => r.length)]
        .fold(0, (a, b) => a > b ? a : b);
    if (columns == 0) return '';

    String cellMd(dynamic cell) {
      if (cell is! Map) return _escapeCell(_cleanText(cell));
      final c = cell.cast<String, dynamic>();
      return _escapeCell(_cleanText(c['#text'] as String? ?? ''));
    }

    String line(List<dynamic> cells) {
      final rendered = List.generate(columns, (i) => i < cells.length ? cellMd(cells[i]) : '');
      return '| ${rendered.join(' | ')} |';
    }

    final lines = [
      header.isEmpty ? '|${'  |' * columns}' : line(header),
      '|${' --- |' * columns}',
      ...rows.map(line),
    ];
    final tableStr = lines.join('\n');
    final title = _cleanText(attrs['titulo'] as String? ?? '');
    return title.isEmpty ? tableStr : '**$title**\n\n$tableStr';
  }

  // ---------------------------------------------------------------- fallback images

  Future<void> _assignFallbackImages(String bookId) async {
    final firstByChapter = <String, String?>{};

    Future<void> assign(String? parentId) async {
      for (final ch in await _repo.listChapters(bookId, parentChapterId: parentId)) {
        await assign(ch.id);
        final first = await _chapterFirstImage(ch.id);
        firstByChapter[ch.id] = first;
        if (first != null && ch.image == null) await _repo.setChapterCover(ch.id, first);
      }
    }

    await assign(null);

    final book = await _repo.getBook(bookId);
    if (book.coverImage != null) return;
    String? first;
    for (final ch in await _repo.listChapters(bookId, parentChapterId: null)) {
      first = firstByChapter[ch.id];
      if (first != null) break;
    }
    if (first != null) await _repo.setBookCover(bookId, first);
  }

  Future<String?> _chapterFirstImage(String chapterId) async {
    final chapter = await _repo.getChapter(chapterId);
    final imageRe = RegExp(r'image://([0-9a-f]{64})');
    for (final m in imageRe.allMatches(chapter.presentation)) { return m.group(1); }
    for (final r in await _repo.listRecipes(chapterId)) {
      final full = await _repo.getRecipe(r.id);
      if (full.image != null) return full.image;
      for (final m in imageRe.allMatches('${full.introduction}${full.preparation}')) {
        return m.group(1);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- helpers

  static List<dynamic> _asList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value;
    return [value];
  }

  static String _cleanText(dynamic value) =>
      (value?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _escapeCell(String text) => text.replaceAll('|', r'\|');
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}

// ---------------------------------------------------------------- image resolver

class _ImageResolver {
  _ImageResolver(this._baseDir, this._imageStore);

  final String _baseDir;
  final ImageStore _imageStore;
  final _cache = <String, String?>{};
  final missing = <String>[];
  int imported = 0;

  Future<String?> resolve(String src) async {
    if (_cache.containsKey(src)) return _cache[src];
    final hash = await _ingest(src);
    _cache[src] = hash;
    if (hash == null) {
      missing.add(src);
    } else {
      imported++;
    }
    return hash;
  }

  Future<String?> _ingest(String src) async {
    final candidate = _findFile(src);
    if (candidate == null) return null;
    try {
      final bytes = await candidate.readAsBytes();
      final result = await _imageStore.ingest(bytes);
      return result['hash'] as String;
    } catch (_) {
      return null;
    }
  }

  File? _findFile(String src) {
    final relative = src.trim().replaceAll(RegExp(r'^\.?/'), '').replaceAll('\\', '/');
    final path = p.join(_baseDir, relative);
    if (File(path).existsSync()) return File(path);
    final dir = Directory(p.dirname(path));
    if (!dir.existsSync()) return null;
    final name = p.basename(path).toLowerCase();
    try {
      for (final entry in dir.listSync()) {
        if (p.basename(entry.path).toLowerCase() == name) return File(entry.path);
      }
    } catch (_) {}
    return null;
  }
}
