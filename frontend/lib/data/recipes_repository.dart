import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/models.dart';

class RecipesRepository {
  RecipesRepository(this._repo);

  final LocalRepository _repo;

  Future<List<ItemSummary>> list(String chapterId) => _repo.listRecipes(chapterId);
  Future<Recipe> get(String id) => _repo.getRecipe(id);
  Future<Recipe> create(String chapterId, Map<String, dynamic> body) =>
      _repo.createRecipe(chapterId, body);
  Future<Recipe> update(String id, Map<String, dynamic> body) =>
      _repo.updateRecipe(id, body);
  Future<void> delete(String id) => _repo.deleteRecipe(id);
  Future<void> reorder(String chapterId, List<String> ids) =>
      _repo.reorderRecipes(chapterId, ids);
}
