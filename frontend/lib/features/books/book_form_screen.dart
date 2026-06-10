import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/block_editor/block_list_editor.dart';

const imagesTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
);

/// Create (bookId == null) or edit (bookId != null) a book.
///
/// Until US4 lands the full block editor, the description field edits the
/// first paragraph block and preserves any other presentation blocks.
class BookFormScreen extends ConsumerStatefulWidget {
  const BookFormScreen({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends ConsumerState<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _coverImage;
  List<ContentBlock> _otherBlocks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.bookId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final book = await ref.read(booksRepositoryProvider).get(widget.bookId!);
    final paragraphIndex = book.presentation.indexWhere((b) => b['type'] == 'paragraph');
    setState(() {
      _titleController.text = book.title;
      _coverImage = book.coverImage;
      if (paragraphIndex >= 0) {
        final spans = (book.presentation[paragraphIndex]['spans'] as List? ?? const [])
            .map((s) => (s as Map)['text'] as String? ?? '')
            .join();
        _descriptionController.text = spans;
        _otherBlocks = [...book.presentation]..removeAt(paragraphIndex);
      } else {
        _otherBlocks = book.presentation;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: const [imagesTypeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final result = await ref.read(apiClientProvider).uploadImage(bytes, file.name);
    setState(() => _coverImage = result['hash'] as String);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final description = _descriptionController.text.trim();
    final presentation = <ContentBlock>[
      if (description.isNotEmpty)
        {
          'type': 'paragraph',
          'spans': [
            {'text': description}
          ],
        },
      ..._otherBlocks,
    ];
    final repo = ref.read(booksRepositoryProvider);
    if (widget.bookId == null) {
      await repo.create(
        title: _titleController.text,
        coverImage: _coverImage,
        presentation: presentation,
      );
    } else {
      await repo.update(
        widget.bookId!,
        title: _titleController.text,
        coverImage: _coverImage,
        presentation: presentation,
      );
    }
    ref.invalidate(bookListProvider);
    if (widget.bookId != null) {
      ref.invalidate(bookDetailProvider(widget.bookId!));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookId == null ? l10n.addBook : l10n.editBook)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(labelText: l10n.title),
                        maxLength: 200,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? l10n.titleRequired : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(labelText: l10n.description),
                        minLines: 3,
                        maxLines: 8,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: Text(_coverImage == null ? l10n.chooseImage : l10n.coverImage),
                          ),
                          if (_coverImage != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => setState(() => _coverImage = null),
                              child: Text(l10n.removeImage),
                            ),
                          ],
                        ],
                      ),
                      if (_coverImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(api.imageUrl(_coverImage!), height: 180),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: Text(l10n.additionalContent),
                        childrenPadding: const EdgeInsets.all(8),
                        children: [
                          BlockListEditor(blocks: _otherBlocks, api: api, onChanged: () {}),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: _save, child: Text(l10n.save)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
