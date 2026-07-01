import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/models.dart';

class ChaptersRepository {
  ChaptersRepository(this._repo);

  final LocalRepository _repo;

  Future<List<ItemSummary>> list(String bookId, {String? parentChapterId}) =>
      _repo.listChapters(bookId, parentChapterId: parentChapterId);

  Future<ChapterDetail> get(String id) => _repo.getChapter(id);

  Future<ChapterDetail> create(
    String bookId, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) => _repo.createChapter(
        bookId,
        title: title,
        parentChapterId: parentChapterId,
        coverImage: coverImage,
        presentation: presentation,
        note: note,
      );

  Future<ChapterDetail> update(
    String id, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) => _repo.updateChapter(
        id,
        title: title,
        parentChapterId: parentChapterId,
        coverImage: coverImage,
        presentation: presentation,
        note: note,
      );

  Future<void> delete(String id) => _repo.deleteChapter(id);

  Future<void> reorder(String bookId, String? parentChapterId, List<String> ids) =>
      _repo.reorderChapters(bookId, parentChapterId, ids);
}
