import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:recetarios/data/local/app_database.dart';

class ImageStore {
  ImageStore(AppDatabase appDb)
      : _db = appDb.db,
        _imagesDir = p.join(appDb.dataDir, 'images');

  final Database _db;
  final String _imagesDir;
  Map<String, String>? _cache; // hash → absolute path

  // Returns the absolute file path for a given hash, or null if not found.
  String? pathFor(String hash) {
    final cache = _cache ??= _buildCache();
    return cache[hash];
  }

  bool exists(String hash) => pathFor(hash) != null;

  // Ingests raw image bytes: computes SHA-256, detects format, writes file.
  // Returns {hash, ext, width, height}.
  Future<Map<String, dynamic>> ingest(Uint8List bytes) async {
    final hash = sha256.convert(bytes).toString();

    if (exists(hash)) {
      final path = pathFor(hash)!;
      return {'hash': hash, 'ext': p.extension(path).replaceFirst('.', '')};
    }

    final ext = _detectExt(bytes);
    final filePath = p.join(_imagesDir, '$hash.$ext');

    int? width, height;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        width = decoded.width;
        height = decoded.height;
      }
    } catch (_) {}

    await File(filePath).writeAsBytes(bytes);

    await _db.insert(
      'images',
      {'hash': hash, 'ext': ext, 'width': width, 'height': height},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    _cache ??= {};
    _cache![hash] = filePath;

    return {'hash': hash, 'ext': ext, 'width': width, 'height': height};
  }

  Map<String, String> _buildCache() {
    final dir = Directory(_imagesDir);
    if (!dir.existsSync()) return {};
    final result = <String, String>{};
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final name = p.basenameWithoutExtension(entity.path);
        result[name] = entity.path;
      }
    }
    return result;
  }

  static String _detectExt(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) { return 'jpg'; }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) { return 'png'; }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) { return 'gif'; }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) { return 'webp'; }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) { return 'bmp'; }
    return 'jpg';
  }
}
