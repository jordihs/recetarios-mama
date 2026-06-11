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
