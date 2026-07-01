import 'package:recetarios/data/local/image_store.dart';

/// Returns a no-op [ImageStore] for widget tests.
/// [pathFor] always returns null (widgets show the broken-image placeholder).
/// Does not use SQLite, so tests remain fast and CI-safe on all platforms.
Future<ImageStore> testImageStore() async {
  return ImageStore.forTest();
}
