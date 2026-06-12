import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';

class ChaptersRepository {
  ChaptersRepository(this._api);

  final ApiClient _api;

  Future<List<ItemSummary>> list(String bookId, {String? parentChapterId}) async {
    final data = await _api.get(
      '/books/$bookId/chapters',
      query: {'parent': ?parentChapterId},
    ) as List;
    return data.map((e) => ItemSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<ChapterDetail> get(String id) async {
    final data = await _api.get('/chapters/$id');
    return ChapterDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ChapterDetail> create(
    String bookId, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    final data = await _api.post('/books/$bookId/chapters', body: {
      'title': title,
      'parent_chapter_id': parentChapterId,
      'cover_image': coverImage,
      'presentation': presentation,
      'note': note,
    });
    return ChapterDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ChapterDetail> update(
    String id, {
    required String title,
    String? parentChapterId,
    String? coverImage,
    String presentation = '',
    String? note,
  }) async {
    final data = await _api.put('/chapters/$id', body: {
      'title': title,
      'parent_chapter_id': parentChapterId,
      'cover_image': coverImage,
      'presentation': presentation,
      'note': note,
    });
    return ChapterDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) => _api.delete('/chapters/$id');

  Future<void> reorder(String bookId, String? parentChapterId, List<String> ids) =>
      _api.put('/chapters/order', body: {
        'book_id': bookId,
        'parent_chapter_id': parentChapterId,
        'ids': ids,
      });
}
