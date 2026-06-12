/// DTOs shared across features. Shapes follow specs/002-recipe-management/contracts/rest-api.md.
library;

/// Summary item used by book, chapter, and recipe lists alike.
class ItemSummary {
  ItemSummary({
    required this.id,
    required this.title,
    this.image,
    this.description = '',
    this.hasSubchapters = false,
    this.recipeCount = 0,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> json) => ItemSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        image: json['cover_image'] as String? ?? json['image'] as String?,
        description: json['description'] as String? ?? '',
        hasSubchapters: json['has_subchapters'] as bool? ?? false,
        recipeCount: json['recipe_count'] as int? ?? 0,
      );

  final String id;
  final String title;
  final String? image;
  final String description;
  final bool hasSubchapters;
  final int recipeCount;
}

class IngredientGroup {
  IngredientGroup({this.title, List<String>? items}) : items = items ?? [];

  factory IngredientGroup.fromJson(Map<String, dynamic> json) => IngredientGroup(
        title: json['title'] as String?,
        items: (json['items'] as List? ?? const []).cast<String>().toList(),
      );

  String? title;
  List<String> items;

  Map<String, dynamic> toJson() => {'title': title, 'items': items};
}

class IngredientsList {
  IngredientsList({this.servings, List<IngredientGroup>? groups}) : groups = groups ?? [];

  factory IngredientsList.fromJson(Map<String, dynamic> json) => IngredientsList(
        servings: json['servings'] as String?,
        groups: (json['groups'] as List? ?? const [])
            .map((g) => IngredientGroup.fromJson((g as Map).cast<String, dynamic>()))
            .toList(),
      );

  String? servings;
  List<IngredientGroup> groups;

  Map<String, dynamic> toJson() =>
      {'servings': servings, 'groups': groups.map((g) => g.toJson()).toList()};
}

class Recipe {
  Recipe({
    required this.id,
    required this.title,
    this.image,
    required this.introduction,
    required this.ingredients,
    required this.preparation,
    this.note,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        image: json['image'] as String?,
        introduction: json['introduction'] as String? ?? '',
        ingredients:
            IngredientsList.fromJson((json['ingredients'] as Map).cast<String, dynamic>()),
        preparation: json['preparation'] as String? ?? '',
        note: json['note'] as String?,
      );

  final String id;
  String title;
  String? image;
  String introduction;
  IngredientsList ingredients;
  String preparation;
  String? note;

  Map<String, dynamic> toJson() => {
        'title': title,
        'image': image,
        'introduction': introduction,
        'ingredients': ingredients.toJson(),
        'preparation': preparation,
        'note': note,
      };
}

class BookDetail {
  BookDetail({
    required this.id,
    required this.title,
    this.coverImage,
    required this.presentation,
    this.note,
  });

  factory BookDetail.fromJson(Map<String, dynamic> json) => BookDetail(
        id: json['id'] as String,
        title: json['title'] as String,
        coverImage: json['cover_image'] as String?,
        presentation: json['presentation'] as String? ?? '',
        note: json['note'] as String?,
      );

  final String id;
  String title;
  String? coverImage;
  String presentation;
  String? note;
}

class ChapterDetail {
  ChapterDetail({
    required this.id,
    required this.bookId,
    this.parentChapterId,
    required this.title,
    this.coverImage,
    required this.presentation,
    this.note,
  });

  factory ChapterDetail.fromJson(Map<String, dynamic> json) => ChapterDetail(
        id: json['id'] as String,
        bookId: json['book_id'] as String,
        parentChapterId: json['parent_chapter_id'] as String?,
        title: json['title'] as String,
        coverImage: json['cover_image'] as String?,
        presentation: json['presentation'] as String? ?? '',
        note: json['note'] as String?,
      );

  final String id;
  final String bookId;
  final String? parentChapterId;
  String title;
  String? coverImage;
  String presentation;
  String? note;
}

class SearchResult {
  SearchResult({
    required this.recipeId,
    required this.title,
    required this.breadcrumb,
    this.snippet = '',
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        recipeId: json['recipe_id'] as String,
        title: json['title'] as String,
        breadcrumb: (json['breadcrumb'] as List? ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        snippet: json['snippet'] as String? ?? '',
      );

  final String recipeId;
  final String title;
  final List<Map<String, dynamic>> breadcrumb;
  final String snippet;
}
