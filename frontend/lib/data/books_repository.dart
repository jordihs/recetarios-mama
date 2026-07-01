import 'package:recetarios/data/local/local_repository.dart';
import 'package:recetarios/data/models.dart';

class BooksRepository {
  BooksRepository(this._repo);

  final LocalRepository _repo;

  Future<List<ItemSummary>> list() => _repo.listBooks();
  Future<BookDetail> get(String id) => _repo.getBook(id);

  Future<BookDetail> create({
    required String title,
    String? coverImage,
    String presentation = '',
    String? note,
  }) => _repo.createBook(
        title: title,
        coverImage: coverImage,
        presentation: presentation,
        note: note,
      );

  Future<BookDetail> update(
    String id, {
    required String title,
    String? coverImage,
    String presentation = '',
    String? note,
  }) => _repo.updateBook(
        id,
        title: title,
        coverImage: coverImage,
        presentation: presentation,
        note: note,
      );

  Future<void> delete(String id) => _repo.deleteBook(id);
  Future<void> reorder(List<String> ids) => _repo.reorderBooks(ids);
}
