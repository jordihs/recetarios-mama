import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

import 'package:recetarios/data/local/app_database.dart';
import 'package:recetarios/data/local/image_store.dart';
import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/local/settings_store.dart';
import 'package:recetarios/data/models.dart';

class PdfService {
  PdfService(AppDatabase appDb, ImageStore imageStore, LocalRepository repo, SettingsStore settings)
      : _db = appDb.db,
        _imageStore = imageStore,
        _repo = repo,
        _settings = settings;

  final Database _db;
  final ImageStore _imageStore;
  final LocalRepository _repo;
  final SettingsStore _settings;

  Future<String> buildRecipePdf(
    String recipeId, {
    bool includeIntroduction = true,
    bool includeImages = true,
    String? outputDir,
  }) async {
    final recipe = await _repo.getRecipe(recipeId);
    final dir = outputDir ?? await _settings.get('pdf_output_dir') ?? Directory.systemTemp.path;
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, _sanitize('${recipe.title}.pdf'));

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => _buildRecipePage(
        recipe,
        includeIntroduction: includeIntroduction,
        includeImages: includeImages,
      ),
    ));

    await File(path).writeAsBytes(await pdf.save());
    return path;
  }

  Future<String> buildBookPdf(String bookId, {String? outputDir}) async {
    final book = await _repo.getBook(bookId);
    final dir = outputDir ?? await _settings.get('pdf_output_dir') ?? Directory.systemTemp.path;
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, _sanitize('${book.title}.pdf'));

    final pdf = pw.Document();

    // Cover page
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(book.title,
                style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
            if (book.presentation.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text(book.presentation, style: const pw.TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    ));

    final chapterRows = await _db.query('chapters',
        where: 'book_id = ? AND parent_chapter_id IS NULL',
        whereArgs: [bookId],
        orderBy: 'position ASC');

    for (final chRow in chapterRows) {
      final chapterId = chRow['id'] as String;
      final chapterTitle = chRow['title'] as String;
      final recipeRows = await _db.query('recipes',
          where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'position ASC');
      if (recipeRows.isEmpty) continue;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Text(chapterTitle,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
      ));

      for (final recRow in recipeRows) {
        final recipe = await _repo.getRecipe(recRow['id'] as String);
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => _buildRecipePage(recipe),
        ));
      }
    }

    await File(path).writeAsBytes(await pdf.save());
    return path;
  }

  List<pw.Widget> _buildRecipePage(
    Recipe recipe, {
    bool includeIntroduction = true,
    bool includeImages = true,
  }) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Text(recipe.title,
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)));
    widgets.add(pw.SizedBox(height: 12));

    if (includeIntroduction && recipe.introduction.isNotEmpty) {
      widgets.add(pw.Text('Introducción',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 6));
      widgets.addAll(_markdownToPdf(recipe.introduction, includeImages: includeImages));
      widgets.add(pw.SizedBox(height: 12));
    }

    final ing = recipe.ingredients;
    if (ing.groups.isNotEmpty) {
      widgets.add(pw.Text('Ingredientes',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 6));
      if (ing.servings != null && ing.servings!.isNotEmpty) {
        widgets.add(pw.Text('Para: ${ing.servings}'));
        widgets.add(pw.SizedBox(height: 4));
      }
      for (final group in ing.groups) {
        if (group.title != null && group.title!.isNotEmpty) {
          widgets.add(pw.Text(group.title!,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
        }
        for (final item in group.items) {
          widgets.add(pw.Text('• $item'));
        }
      }
      widgets.add(pw.SizedBox(height: 12));
    }

    if (recipe.preparation.isNotEmpty) {
      widgets.add(pw.Text('Preparación',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 6));
      widgets.addAll(_markdownToPdf(recipe.preparation, includeImages: includeImages));
      widgets.add(pw.SizedBox(height: 12));
    }

    if (recipe.note != null && recipe.note!.isNotEmpty) {
      widgets.add(pw.Text('Notas',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 6));
      widgets.addAll(_markdownToPdf(recipe.note!, includeImages: includeImages));
    }

    return widgets;
  }

  List<pw.Widget> _markdownToPdf(String markdown, {bool includeImages = true}) {
    final widgets = <pw.Widget>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        widgets.add(pw.Text(text));
        widgets.add(pw.SizedBox(height: 6));
      }
      buffer.clear();
    }

    for (final line in markdown.split('\n')) {
      if (line.startsWith('## ')) {
        flushBuffer();
        widgets.add(pw.Text(line.substring(3),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
        continue;
      }
      if (line.startsWith('### ')) {
        flushBuffer();
        widgets.add(pw.Text(line.substring(4),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushBuffer();
        widgets.add(pw.Text('• ${line.substring(2)}'));
        continue;
      }
      final imgMatch =
          RegExp(r'!\[([^\]]*)\]\(image://([0-9a-fA-F]{64})\)').firstMatch(line);
      if (imgMatch != null) {
        flushBuffer();
        if (includeImages) {
          final hash = imgMatch.group(2)!;
          final caption = imgMatch.group(1) ?? '';
          final imgPath = _imageStore.pathFor(hash);
          if (imgPath != null) {
            try {
              final imgBytes = Uint8List.fromList(File(imgPath).readAsBytesSync());
              widgets.add(pw.Image(pw.MemoryImage(imgBytes), width: 400));
              if (caption.isNotEmpty) {
                widgets.add(pw.Text(caption, style: const pw.TextStyle(fontSize: 10)));
              }
              widgets.add(pw.SizedBox(height: 8));
            } catch (_) {}
          }
        }
        continue;
      }
      buffer.writeln(line);
    }
    flushBuffer();
    return widgets;
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
}
