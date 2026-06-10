import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';

class BooksRepository {
  BooksRepository(this._api);

  final ApiClient _api;

  Future<List<ItemSummary>> list() async {
    final data = await _api.get('/books') as List;
    return data.map((e) => ItemSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<BookDetail> get(String id) async {
    final data = await _api.get('/books/$id');
    return BookDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<BookDetail> create({
    required String title,
    String? coverImage,
    List<ContentBlock> presentation = const [],
  }) async {
    final data = await _api.post('/books', body: {
      'title': title,
      'cover_image': coverImage,
      'presentation': presentation,
    });
    return BookDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<BookDetail> update(
    String id, {
    required String title,
    String? coverImage,
    List<ContentBlock> presentation = const [],
  }) async {
    final data = await _api.put('/books/$id', body: {
      'title': title,
      'cover_image': coverImage,
      'presentation': presentation,
    });
    return BookDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) => _api.delete('/books/$id');

  Future<void> reorder(List<String> ids) => _api.put('/books/order', body: {'ids': ids});
}
