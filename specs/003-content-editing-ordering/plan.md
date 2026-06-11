# Implementation Plan: Content Editing & Legacy Ordering

**Branch**: `003-content-editing-ordering` | **Date**: 2026-06-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-content-editing-ordering/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the per-block rich-content model with **markdown documents** as the canonical storage for all rich content (book/chapter introductions, recipe introduction and preparation), driven by the corrected legacy schema v2 whose `CONTENIDO` arrays preserve original element order. The importer reads only v2 (v1 rejected), collapses each introduction into one markdown document (notes excluded into a new `note` field), maps multi-title intros to an H2/H3 hierarchy, and assigns fallback images to imageless books/chapters from their subtrees (never recipes). Editing moves to a single rich text editor per section (WYSIWYG default, unobtrusive raw-source view), eliminating per-paragraph editing. Two display fixes ride along: imageless cards show more text, and table cells containing images bottom-align their text on screen and in PDFs. No data migration: old-format libraries get a reset offer; old backup archives are rejected.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.44 (existing frontend); Python 3.12 (existing backend) — unchanged

**Primary Dependencies**: NEW backend: `markdown-it-py` + `mdit-py-plugins` (CommonMark + GFM-tables parsing for PDF/FTS/description). NEW frontend: `package:markdown` (Dart team; parse to AST for the custom renderer), `appflowy_editor` (WYSIWYG editing surface with markdown import/export). Everything else (FastAPI, SQLite/FTS5, ReportLab, Riverpod, go_router, dio) unchanged

**Storage**: Same SQLite database; schema bumped to `user_version = 2`: rich-content columns (`books.presentation`, `chapters.presentation`, `recipes.introduction`, `recipes.preparation`) become **markdown TEXT**, new `books.note` / `chapters.note` columns; v1 databases are detected and offered a reset (no migration). Library archive `format_version` bumped to 2; v1 archives rejected. Image references inside markdown use `image://<sha256>` URIs resolved against the existing content-addressed store

**Testing**: Existing harnesses (pytest + golden imports against the updated `legacy/` v2 books; flutter widget tests). Golden tests rewritten for ordered output; new unit tests for v2→markdown emission, markdown→flowables, markdown→plain-text extraction

**Target Platform**: Windows desktop (unchanged); Android/Linux paths unaffected

**Project Type**: Same two projects (`backend/`, `frontend/`) — no structural change

**Performance Goals**: Unchanged from feature 002 (search <1 s, book PDF <2 min, recipe PDF <15 s end-to-end, toggle <100 ms); markdown parsing adds negligible cost at this scale

**Constraints**: Offline, Spanish UI, UTF-8, English code/docs — all unchanged. Markdown dialect fixed to CommonMark + GFM tables (both parsers support it identically)

**Scale/Scope**: Same library scale; touches importer, storage layer, API content shapes, renderer, editor, PDF builders, FTS extraction, plus two visual fixes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Assessment | Status |
|---|-----------|------------|--------|
| I | Code Quality First | Markdown replaces a custom block model with a standard format; one canonical representation feeding all consumers | PASS |
| II | Testing Excellence | TDD continues: golden tests against the real v2 books are the core guarantee of ordering preservation (SC-001); unit tests for each markdown mapping | PASS |
| III | UX Consistency | One editor component for every rich-content section; same save/discard semantics; Spanish strings via existing l10n pipeline | PASS |
| IV | Performance & Efficiency | Existing targets re-validated by the perf script after the change | PASS |
| V | Simplicity (YAGNI) | No migration code (clarified); v1 import path deleted, not maintained; one new editor dependency justified below | PASS (see Complexity Tracking) |
| VI | Language Standards | Unchanged | PASS |

**Post-Phase-1 re-check**: design artifacts introduce one heavyweight frontend dependency (`appflowy_editor`) with a documented containment strategy and fallback — justified in Complexity Tracking; still PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-content-editing-ordering/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── api-changes.md   # Phase 1 output (delta over 002's rest-api.md)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
backend/src/recetarios/
├── models/
│   └── markdown.py            # NEW: markdown helpers (parse, plain-text, first-paragraph, image refs)
├── services/
│   ├── legacy_import/
│   │   ├── parser.py          # CHANGED: v2 validation (CONTENIDO required), v1 detection+rejection
│   │   ├── mapper.py          # REWRITTEN: ordered CONTENIDO → markdown emission, notes split, H2/H3 titles
│   │   └── importer.py        # CHANGED: image fallback pass (book/chapter), incomplete recipes
│   ├── pdf/
│   │   ├── base.py            # CHANGED: markdown → Platypus flowables (markdown-it tokens), VALIGN BOTTOM for image cells
│   │   ├── book_builder.py    # CHANGED: consumes markdown presentation
│   │   └── recipe_builder.py  # CHANGED: include-flags operate on markdown sections
│   ├── archive.py             # CHANGED: format_version 2; v1 archives rejected
│   └── library.py             # CHANGED: markdown columns, note fields, description/FTS from markdown
├── storage/
│   ├── db.py                  # CHANGED: schema v2, v1 detection (no auto-migrate)
│   └── repository.py          # CHANGED: note columns, FTS text extraction from markdown
└── api/
    ├── library_status.py      # NEW: GET /library/status, POST /library/reset (old-format reset flow)
    └── (books/chapters/recipes routers: content fields become markdown strings + note)

frontend/lib/
├── widgets/
│   ├── markdown_view.dart     # NEW: AST-based renderer (replaces block_renderer.dart): headings, paragraphs,
│   │                          #      image:// images w/ captions, consecutive-image grids, tables w/ bottom-aligned image cells
│   ├── markdown_editor.dart   # NEW: WYSIWYG (appflowy_editor) + unobtrusive source view (replaces block_editor/)
│   └── item_card.dart         # CHANGED: imageless cards expand description area
├── features/
│   ├── books|chapters forms   # CHANGED: description+blocks replaced by one markdown editor + note field
│   ├── recipes/               # CHANGED: edit form uses markdown editors for intro/preparation
│   └── library_reset/         # NEW: old-format detection dialog + reset flow
└── data/models.dart           # CHANGED: content fields as String markdown, note fields
```

**Structure Decision**: Same two-project layout; this feature is a content-representation swap inside existing modules plus one new editor/renderer widget pair and a small library-status API.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New heavyweight dependency `appflowy_editor` | Spec requires WYSIWYG-default editing ("preview by default, source not prominent") with toolbar formatting — a from-scratch Flutter WYSIWYG is far costlier and riskier | Plain source-TextField with preview toggle fails the spec's "preview is the default editing surface" requirement; containment: markdown stays canonical, the editor is one swappable widget, and structures it can't represent round-trip through a read-only raw block editable in source view (see research R3) |
