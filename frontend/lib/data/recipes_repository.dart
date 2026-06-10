import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/data/models.dart';

class RecipesRepository {
  RecipesRepository(this._api);

  final ApiClient _api;

  Future<List<ItemSummary>> list(String chapterId) async {
    final data = await _api.get('/chapters/$chapterId/recipes') as List;
    return data.map((e) => ItemSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Recipe> get(String id) async {
    final data = await _api.get('/recipes/$id');
    return Recipe.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Recipe> create(String chapterId, Map<String, dynamic> body) async {
    final data = await _api.post('/chapters/$chapterId/recipes', body: body);
    return Recipe.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Recipe> update(String id, Map<String, dynamic> body) async {
    final data = await _api.put('/recipes/$id', body: body);
    return Recipe.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) => _api.delete('/recipes/$id');

  Future<void> reorder(String chapterId, List<String> ids) =>
      _api.put('/recipes/order', body: {'chapter_id': chapterId, 'ids': ids});
}
