# Quickstart: Content Editing & Legacy Ordering

**Feature**: `003-content-editing-ordering` | **Date**: 2026-06-11

Development setup is identical to feature 002 (`specs/002-recipe-management/quickstart.md`). Deltas:

## New dependencies

```powershell
# Backend (after pulling this feature's pyproject change)
cd backend; .venv\Scripts\Activate.ps1; pip install -e .[dev]   # adds markdown-it-py, mdit-py-plugins

# Frontend
cd frontend; flutter pub get                                     # adds appflowy_editor, markdown
```

## Manual smoke (this feature)

1. Start dev backend + frontend with a **fresh data dir** (`--data-dir ..\.devdata3`).
2. Import `legacy/recetas_de_mama.json` → open the book: the introduction must read top-to-bottom in the same order as the source file's `CONTENIDO` (titles interleaved with paragraphs, gallery at the position it occurs).
3. Check a multi-title introduction (e.g., in `las_setas_como_ingrediente_principal.json`): first title visibly larger (H2) than later ones (H3).
4. The book card shows an image even though the source book has none at the root (fallback from contents); recipes without images remain imageless.
5. Edit a chapter introduction: single rich editor opens in formatted mode; toolbar has bold/headings/list/table/image; the small "fuente" toggle shows raw markdown; there is no "Añadir párrafo" button anywhere.
6. Cards without images show roughly twice the description text.
7. Open an imported table mixing image and text cells: texts sit at the cell bottoms, evenly. Print the recipe/book to PDF and verify the same alignment.
8. Point the app at a **pre-change data dir** (from feature 002): a Spanish dialog explains the library predates the new format and offers reset; after reset + re-import everything works.
9. Try importing an old-format backup archive: clear Spanish rejection.

## Test commands

Unchanged: `pytest` (backend), `flutter analyze && flutter test` (frontend), `backend/tests/perf_check.py` for the performance re-check.

## Validated

**Date**: 2026-06-12 | Backend: 131 pytest green; frontend: `flutter analyze` clean, 24 widget tests green, e2e `integration_test` green on Windows against a live dev backend (fresh data dir, real app launch, book creation through the new form).

| Step | Evidence |
|---|---|
| 1. Fresh data dir, dev backend + frontend | e2e run: real app launched on Windows against a fresh-dir dev backend |
| 2. Import order matches source `CONTENIDO` | machine-checked stronger than manual: `tests/golden/test_legacy_import.py::test_introduction_order_matches_source` verifies *every* introduction of all 3 real books |
| 3. Multi-title intro → H2 then H3 | golden `test_multi_title_intro_h2_then_h3`; renderer maps h2→titleLarge, h3→titleMedium (`markdown_view.dart`) |
| 4. Book/chapter image fallback; recipes never | golden `tests/golden/test_image_fallback.py` (3 books + synthetic imageless case) |
| 5. Single rich editor, WYSIWYG default, fuente toggle, no "Añadir párrafo" | widget tests `test/widgets/markdown_editor_test.dart` (5) + `recipe_edit_test.dart`; `BlockListEditor` deleted from the codebase |
| 6. Imageless cards ≈ double text | widget test asserts imageless `maxLines ≥ 2×` with-image cards (`book_list_test.dart`) |
| 7. Image-cell bottom alignment, screen + PDF | widget test `markdown_view_test.dart` + unit `test_pdf_table_alignment.py` (exact per-cell VALIGN); PDF generation e2e in `test_book_pdf.py`/`test_recipe_pdf.py` |
| 8. Pre-v2 data dir → Spanish reset flow | backend `test_library_status_api.py` (9: status/guard/reset/images preserved) + widget test `library_reset_gate_test.dart` (gate blocks UI, Spanish dialog, confirm required) |
| 9. Old backup archive → Spanish rejection | `test_library_archive.py::test_v1_archive_rejected` (`archive_unsupported_version`) |

Visual fit-and-finish (relative type sizes, card balance) was exercised through the rendering widget tests and the Windows e2e launch; final eyeballing happens naturally on first real use with the family library.
