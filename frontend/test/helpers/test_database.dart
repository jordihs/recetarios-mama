import 'package:recetarios/data/local/app_database.dart';
import 'package:recetarios/data/local/image_store.dart';

/// Returns an isolated, empty in-memory [ImageStore] for widget tests.
/// The image store always returns null for any hash (no images stored),
/// which causes widgets to show the broken-image placeholder instead of
/// trying to open real files on disk.
Future<ImageStore> testImageStore() async {
  final db = await AppDatabase.openInMemory();
  return ImageStore(db);
}
