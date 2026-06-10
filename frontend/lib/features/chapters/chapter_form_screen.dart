import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recetarios/app/providers.dart';
import 'package:recetarios/data/models.dart';
import 'package:recetarios/features/books/book_form_screen.dart' show imagesTypeGroup;
import 'package:recetarios/features/chapters/chapter_list_screen.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/block_editor/block_list_editor.dart';

/// Create (chapterId == null) or edit a chapter. The parent (book + optional
/// parent chapter) comes from the navigation context and is not editable here.
class ChapterFormScreen extends ConsumerStatefulWidget {
  const ChapterFormScreen({
    super.key,
    required this.bookId,
    this.chapterId,
    this.parentChapterId,
  });

  final String bookId;
  final String? chapterId;
  final String? parentChapterId;

  @override
  ConsumerState<ChapterFormScreen> createState() => _ChapterFormScreenState();
}

class _ChapterFormScreenState extends ConsumerState<ChapterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _coverImage;
  String? _parentChapterId;
  List<ContentBlock> _otherBlocks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _parentChapterId = widget.parentChapterId;
    if (widget.chapterId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final chapter = await ref.read(chaptersRepositoryProvider).get(widget.chapterId!);
    final paragraphIndex = chapter.presentation.indexWhere((b) => b['type'] == 'paragraph');
    setState(() {
      _titleController.text = chapter.title;
      _coverImage = chapter.coverImage;
      _parentChapterId = chapter.parentChapterId;
      if (paragraphIndex >= 0) {
        _descriptionController.text =
            ((chapter.presentation[paragraphIndex]['spans'] as List? ?? const [])
                .map((s) => (s as Map)['text'] as String? ?? '')).join();
        _otherBlocks = [...chapter.presentation]..removeAt(paragraphIndex);
      } else {
        _otherBlocks = chapter.presentation;
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
    final repo = ref.read(chaptersRepositoryProvider);
    if (widget.chapterId == null) {
      await repo.create(
        widget.bookId,
        title: _titleController.text,
        parentChapterId: _parentChapterId,
        coverImage: _coverImage,
        presentation: presentation,
      );
    } else {
      await repo.update(
        widget.chapterId!,
        title: _titleController.text,
        parentChapterId: _parentChapterId,
        coverImage: _coverImage,
        presentation: presentation,
      );
    }
    ref.invalidate(chapterListProvider((bookId: widget.bookId, parentId: _parentChapterId)));
    if (widget.chapterId != null) {
      ref.invalidate(chapterDetailProvider(widget.chapterId!));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.chapterId == null ? l10n.addChapter : l10n.editChapter)),
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
                          TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
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
