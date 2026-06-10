import 'package:go_router/go_router.dart';

import 'package:recetarios/features/books/book_form_screen.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/features/chapters/chapter_form_screen.dart';
import 'package:recetarios/features/chapters/chapter_list_screen.dart';
import 'package:recetarios/features/recipes/recipe_list_section.dart';
import 'package:recetarios/features/recipes/recipe_view_screen.dart';
import 'package:recetarios/features/search/search_screen.dart';
import 'package:recetarios/features/settings/settings_screen.dart';

/// Route map (research R9):
///   /books                                  book list (home)
///   /books/new, /books/:bookId/edit         book form
///   /books/:bookId                          top-level chapter list
///   /books/:bookId/chapters/:chapterId      chapter (subchapters + recipes)
///   .../recipes/:recipeId                   recipe view
/// Remaining routes are added by their feature phases.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/books',
    routes: [
      GoRoute(path: '/books', builder: (context, state) => const BookListScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/books/new', builder: (context, state) => const BookFormScreen()),
      GoRoute(
        path: '/books/:bookId/edit',
        builder: (context, state) => BookFormScreen(bookId: state.pathParameters['bookId']),
      ),
      GoRoute(
        path: '/books/:bookId',
        builder: (context, state) =>
            ChapterListScreen(bookId: state.pathParameters['bookId']!),
      ),
      GoRoute(
        path: '/books/:bookId/chapters/new',
        builder: (context, state) => ChapterFormScreen(
          bookId: state.pathParameters['bookId']!,
          parentChapterId: state.uri.queryParameters['parent'],
        ),
      ),
      GoRoute(
        path: '/books/:bookId/chapters/:chapterId/edit',
        builder: (context, state) => ChapterFormScreen(
          bookId: state.pathParameters['bookId']!,
          chapterId: state.pathParameters['chapterId'],
        ),
      ),
      GoRoute(
        path: '/books/:bookId/chapters/:chapterId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return ChapterListScreen(
            bookId: bookId,
            chapterId: chapterId,
            recipesSection: RecipeListSection(bookId: bookId, chapterId: chapterId),
          );
        },
      ),
      GoRoute(
        path: '/books/:bookId/chapters/:chapterId/recipes/:recipeId',
        builder: (context, state) =>
            RecipeViewScreen(recipeId: state.pathParameters['recipeId']!),
      ),
    ],
  );
}
