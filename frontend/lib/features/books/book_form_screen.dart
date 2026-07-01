import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/features/books/book_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor.dart';

const imagesTypeGroup = XTypeGroup(
  label: 'Imágenes',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
);

class BookFormScreen extends ConsumerStatefulWidget {
  const BookFormScreen({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends ConsumerState<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String _content = '';
  String? _coverImage;
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
    setState(() {
      _titleController.text = book.title;
      _content = book.presentation;
      _noteController.text = book.note ?? '';
      _coverImage = book.coverImage;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: const [imagesTypeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final result = await ref.read(imageStoreProvider).ingest(bytes);
    setState(() => _coverImage = result['hash'] as String);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    final repo = ref.read(booksRepositoryProvider);
    if (widget.bookId == null) {
      await repo.create(
        title: _titleController.text,
        coverImage: _coverImage,
        presentation: _content,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repo.update(
        widget.bookId!,
        title: _titleController.text,
        coverImage: _coverImage,
        presentation: _content,
        note: note.isEmpty ? null : note,
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
    final imageStore = ref.watch(imageStoreProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookId == null ? l10n.addBook : l10n.editBook)),
      bottomNavigationBar: _loading
          ? null
          : Material(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
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
              ),
            ),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.content,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      const SizedBox(height: 4),
                      MarkdownEditor(
                        initialMarkdown: _content,
                        imageStore: imageStore,
                        onChanged: (value) => _content = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(labelText: l10n.note),
                        minLines: 2,
                        maxLines: 4,
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
                        Builder(builder: (context) {
                          final filePath = imageStore.pathFor(_coverImage!);
                          if (filePath == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(filePath), height: 180),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
