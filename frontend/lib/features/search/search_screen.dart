import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/l10n/app_localizations.dart';

/// Full-text search over the whole library (FR-036..038).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchResult>? _results;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _query = '';
      });
      return;
    }
    final data = await ref.read(apiClientProvider).get('/search', query: {'q': query}) as List;
    if (!mounted) return;
    setState(() {
      _query = query;
      _results = data
          .map((e) => SearchResult.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    });
  }

  void _open(SearchResult result) {
    final chapters = result.breadcrumb.where((s) => s['type'] == 'chapter').toList();
    final book = result.breadcrumb.firstWhere((s) => s['type'] == 'book');
    if (chapters.isEmpty) return;
    final chapterId = chapters.last['id'] as String;
    context.push(
        '/books/${book['id']}/chapters/$chapterId/recipes/${result.recipeId}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.searchHint, border: InputBorder.none),
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: _run,
        ),
      ),
      body: results == null
          ? const SizedBox.shrink()
          : results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child:
                        Text(l10n.searchNoResults(_query), textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final result = results[i];
                    final breadcrumb =
                        results[i].breadcrumb.map((s) => s['title']).join(' › ');
                    return ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text(result.title),
                      subtitle: Text(
                        result.snippet.isEmpty
                            ? breadcrumb
                            : '$breadcrumb\n${result.snippet}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _open(result),
                    );
                  },
                ),
    );
  }
}
