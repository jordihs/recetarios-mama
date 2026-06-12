# Tasks: Content Editing & Legacy Ordering

**Input**: Design documents from `/specs/003-content-editing-ordering/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-changes.md, quickstart.md

**Tests**: Included — constitution Principle II (Testing Excellence, TDD preferred). Test tasks are written FIRST and must FAIL before their implementation tasks. This feature also *rewrites* existing 002 tests whose payload shapes change; those rewrites live in the Foundational phase because every story depends on a green baseline.

**Organization**: Tasks grouped by user story (US1–US5 from spec.md). The storage-format swap (blocks → markdown) is the blocking Foundational phase: US1 and US2 are meaningless without it, and the app must compile/run at every checkpoint.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1…US5
- Exact file paths in every description

## Path Conventions

Existing two-project layout: `backend/` (Python, package `recetarios` under `backend/src/`), `frontend/` (Flutter). Baseline architecture from feature 002 remains.

---

## Phase 1: Setup

**Purpose**: New dependencies available in both projects

- [X] T001 Add `markdown-it-py` and `mdit-py-plugins` to `backend/pyproject.toml` dependencies and install into `backend/.venv` (`pip install -e .[dev]`)
- [X] T002 [P] Add `appflowy_editor` and `markdown` to `frontend/pubspec.yaml` and run `flutter pub get`; record the resolved appflowy_editor version in the PR notes (research R3 containment)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Markdown becomes the canonical content representation end to end (storage → API → rendering), with the v1-library reset flow in place. The app compiles and all suites are green at the checkpoint, with interim plain-markdown editing.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Implement markdown helpers in `backend/src/recetarios/models/markdown.py` (`plain_text`, `first_paragraph`, `referenced_images` over markdown-it tokens with GFM tables; `image://` URI handling per data-model.md) with unit tests in `backend/tests/unit/test_markdown_helpers.py` (tests first, failing)
- [X] T004 Update `backend/src/recetarios/storage/db.py` to schema v2: markdown TEXT content columns, `books.note`/`chapters.note`, `user_version = 2`, and a `format` probe (fresh→v2, existing v1 detected but never touched/migrated); unit test in `backend/tests/unit/test_db_version.py`
- [X] T005 Replace block models with markdown fields in `backend/src/recetarios/models/entities.py` (`presentation`/`introduction`/`preparation`: `str`, ≤ 1 MB; `note: str | None` on Book/Chapter inputs). Do NOT delete `models/blocks.py` yet — `legacy_import/mapper.py` and `archive.py` still import it until US1 rewires them (deletion happens in T021); the backend must start at every point in this phase
- [X] T006 Update `backend/src/recetarios/storage/repository.py`: markdown columns, note columns, FTS text extraction via `models/markdown.py` (titles+ingredients unchanged; note appended to FTS introduction text per data-model.md)
- [X] T007 Update `backend/src/recetarios/services/library.py`: markdown validation (image refs exist, size cap), description derivation via `first_paragraph`, note fields in summaries/details
- [X] T008 Rewrite payload shapes in routers (`backend/src/recetarios/api/books.py`, `chapters.py`, `recipes.py` — mostly via T005 models) and rewrite the affected integration tests to markdown payloads: `backend/tests/integration/test_books_api.py`, `test_chapters_api.py`, `test_recipes_api.py`, `test_recipes_write_api.py`, `test_search_api.py`. Explicitly keep/port these assertions: list `description` derives from the first markdown paragraph (FR-013), book/chapter `note` round-trips, note text is findable via `/search`, and accent-insensitive matching is preserved
- [X] T009 Implement legacy-library guard per contracts/api-changes.md: `GET /library/status`, `POST /library/reset` (confirm required; recreates DB at v2, keeps images dir) in `backend/src/recetarios/api/library_status.py`, `409 library_format_legacy` guard on all other routes, new Spanish messages (`legacy_v1_unsupported`, `archive_unsupported_version`, `library_format_legacy`, `reset_confirm_required`) in `backend/src/recetarios/l10n/messages.py`; integration tests in `backend/tests/integration/test_library_status_api.py` (tests first, failing)
- [X] T010 Rewrite PDF generation over markdown in `backend/src/recetarios/services/pdf/base.py` (markdown-it tokens → existing flowable vocabulary: headings, paragraphs, emphasis, lists, image lines, gallery paragraphs → grids, GFM tables incl. image cells) and adapt `book_builder.py`/`recipe_builder.py`; update `backend/tests/integration/test_book_pdf.py` and `test_recipe_pdf.py` fixtures to markdown content
- [X] T011 [P] Update frontend DTOs in `frontend/lib/data/models.dart`: content fields as `String` markdown, `note` on `BookDetail`/`ChapterDetail`; remove `ContentBlock` typedef and block helpers
- [X] T012 [P] Implement `frontend/lib/widgets/markdown_view.dart` (package:markdown AST → widgets: H2/H3, paragraphs with bold/italic, lists, `image://` images with captions and semantic labels from alt text, consecutive-image grids, GFM tables) and replace `BlockRenderer` usages in `frontend/lib/features/recipes/recipe_view_screen.dart` and `frontend/lib/features/chapters/chapter_list_screen.dart`; delete `frontend/lib/widgets/block_renderer.dart`
- [X] T013 Switch forms to interim markdown editing: `frontend/lib/features/books/book_form_screen.dart`, `frontend/lib/features/chapters/chapter_form_screen.dart` (one multiline markdown field + note field, replacing description+block expansion), `frontend/lib/features/recipes/recipe_edit_form.dart` (markdown fields for intro/preparation); delete `frontend/lib/widgets/block_editor/` and the "Añadir párrafo" interaction everywhere
- [X] T014 Implement frontend reset flow in `frontend/lib/features/library_reset/library_reset_gate.dart`: startup `GET /library/status` check wrapping the router, Spanish explanation dialog, confirmed `POST /library/reset`, Spanish l10n strings in `frontend/l10n/app_es.arb`
- [X] T015 Update existing widget tests to markdown shapes (`frontend/test/features/books/book_list_test.dart`, `chapters/chapter_list_test.dart`, `recipes/recipe_view_test.dart`, `recipes/recipe_edit_test.dart`) — full `flutter analyze` + `flutter test` + backend `pytest` green checkpoint (legacy import tests may be temporarily skipped pending US1)

**Checkpoint**: App runs on markdown storage end to end; old-format library triggers the reset flow; both suites green

---

## Phase 3: User Story 1 - Ordered Legacy Import (Schema v2) (Priority: P1) 🎯 MVP

**Goal**: Import reads only v2 `CONTENIDO` arrays, preserving element order; multi-title → H2/H3; notes split out; incomplete recipes accepted; v1 files and v1 archives rejected

**Independent Test**: Import the three updated sample books; verify per-introduction element order equals source order; multi-title hierarchy; notes shown separately; v1 file rejection (spec US1 scenarios, SC-001/002)

### Tests for User Story 1 (write first, must fail) ⚠️

- [X] T016 [P] [US1] Rewrite golden tests in `backend/tests/golden/test_legacy_import.py`: machine-check that each imported introduction's markdown element sequence equals the source `CONTENIDO` sequence (SC-001); multi-title H2-then-H3 assertions; NOTA blocks land in `note` fields not the body; counting/preservation tests retained; incomplete-recipe and NOTA-array cases; v1-shaped document → `legacy_v1_unsupported`
- [X] T017 [P] [US1] Rewrite unit tests in `backend/tests/unit/test_legacy_parser.py`: v2 validation, per-block markdown emission (PARRAFO whitespace, IMAGEN caption, IMAGENES gallery lines, TABLA with image cells + bold title line, TITULO first/subsequent levels), v1 marker detection

### Implementation for User Story 1

- [X] T018 [US1] Update `backend/src/recetarios/services/legacy_import/parser.py`: v2 shape validation (`CONTENIDO` arrays), v1 marker detection → `ApiError("legacy_v1_unsupported")`
- [X] T019 [US1] Rewrite `backend/src/recetarios/services/legacy_import/mapper.py`: ordered `CONTENIDO` walk emitting markdown per data-model.md mapping table; notes collected separately; recipe mapping tolerates missing INGREDIENTES/PREPARACION and joins NOTA arrays
- [X] T020 [US1] Update `backend/src/recetarios/services/legacy_import/importer.py`: store markdown + note fields, missing-image reporting unchanged, golden tests green (T016/T017)
- [X] T021 [US1] Bump archive to `format_version: 2` in `backend/src/recetarios/services/archive.py` (markdown + note fields; v1 archives → `archive_unsupported_version`) and update `backend/tests/integration/test_library_archive.py` round-trip + rejection tests; then delete `backend/src/recetarios/models/blocks.py` — its last consumers (mapper T019, archive here) are now rewired (closes the deferral from T005)

**Checkpoint**: The real family books import with verified source-order fidelity — MVP of this feature

---

## Phase 4: User Story 2 - Single-Document Rich Text Editing (Priority: P2)

**Goal**: Every rich content section edited as one document in a WYSIWYG-default editor (toolbar: bold, headings, lists, tables, images) with an unobtrusive source view; no per-paragraph controls anywhere

**Independent Test**: Edit a book introduction: write paragraphs + subsection + bold + list + image in one surface; toggle source and back; save; verify render (spec US2 scenarios, SC-003/004)

### Tests for User Story 2 (write first, must fail) ⚠️

- [X] T022 [P] [US2] Write failing widget tests in `frontend/test/widgets/markdown_editor_test.dart`: opens in WYSIWYG mode by default; source toggle reveals raw markdown and syncs edits back; toolbar bold/heading/list actions produce the expected markdown; image insertion inserts an `image://` ref; and in `frontend/test/features/recipes/recipe_edit_test.dart`: no "Añadir párrafo" exists, save/discard semantics preserved

### Implementation for User Story 2

- [X] T023 [US2] Implement `frontend/lib/widgets/markdown_editor.dart`: appflowy_editor surface with markdown decode on open / encode on change; toolbar (bold, italic, H2, H3, bulleted list, table, image via existing upload); unsupported constructs (e.g., image-cell tables) preserved as protected raw blocks (research R3)
- [X] T024 [US2] Add the unobtrusive source view to `frontend/lib/widgets/markdown_editor.dart`: small "fuente" toggle → monospace TextField over the canonical markdown, bidirectional sync, preview/WYSIWYG remains the default mode (FR-010)
- [X] T025 [US2] Replace the interim markdown TextFields with `MarkdownEditor` in `frontend/lib/features/books/book_form_screen.dart`, `frontend/lib/features/chapters/chapter_form_screen.dart`, and `frontend/lib/features/recipes/recipe_edit_form.dart` (introduction + preparation), keeping dirty-tracking/save/discard wiring
- [X] T026 [US2] Editor l10n strings and accessibility (constitution WCAG gate): Spanish tooltips + semantic labels on every toolbar button and the source toggle, focus order through the editor, in `frontend/l10n/app_es.arb` and `frontend/lib/widgets/markdown_editor.dart`; `flutter analyze` + full widget suite green (T022 passing)

**Checkpoint**: All rich content edited through the single-document editor

---

## Phase 5: User Story 3 - Image Fallback on Import (Priority: P3)

**Goal**: Imported books/chapters without a valid image inherit the first image found in their subtree (document order); recipes never inherit

**Independent Test**: Import a sample book with an imageless root; book card shows a content image; synthetic no-image-anywhere case stays imageless; recipes unchanged (spec US3 scenarios, SC-005)

### Tests for User Story 3 (write first, must fail) ⚠️

- [X] T027 [P] [US3] Write failing tests in `backend/tests/golden/test_image_fallback.py`: for each sample book, every book/chapter with ≥1 image in its subtree ends with an image and it equals the first one in document order; recipes never receive fallbacks; synthetic fixture with no images anywhere imports cleanly imageless

### Implementation for User Story 3

- [X] T028 [US3] Implement the fallback pass in `backend/src/recetarios/services/legacy_import/importer.py`: depth-first document-order walk over resolved `image://` refs (own content → recipes (cover then content) → subchapters), assigning `cover_image` to imageless books/chapters only

**Checkpoint**: Imported library looks populated; fallback rules verified against real data

---

## Phase 6: User Story 4 - Fuller Text on Imageless Cards (Priority: P4)

**Goal**: Cards without images use the image's space for more description text; cards with images unchanged

**Independent Test**: Same long description with and without image side by side: imageless card shows at least double the lines (spec US4 scenarios, SC-006)

### Tests for User Story 4 (write first, must fail) ⚠️

- [X] T029 [P] [US4] Write failing widget test in `frontend/test/features/books/book_list_test.dart`: imageless card's visible description maxLines ≥ 2× the with-image card's; with-image layout unchanged

### Implementation for User Story 4

- [X] T030 [US4] Update `frontend/lib/widgets/item_card.dart`: when `imageUrl == null`, description expands into the image area (LayoutBuilder-computed maxLines), ellipsis truncation retained

**Checkpoint**: Lists look balanced with or without images

---

## Phase 7: User Story 5 - Aligned Table Cells With Images (Priority: P5)

**Goal**: Table cells containing images bottom-align their text — on screen and in generated PDFs

**Independent Test**: Render and print a table mixing image+text cells of varying image heights; texts sit at a uniform bottom baseline (spec US5 scenarios, SC-007)

### Tests for User Story 5 (write first, must fail) ⚠️

- [X] T031 [P] [US5] Write failing tests: widget test in `frontend/test/widgets/markdown_view_test.dart` (image-bearing cells use bottom vertical alignment; text-only cells unchanged) and backend test in `backend/tests/unit/test_pdf_table_alignment.py` (generated table style contains bottom VALIGN entries exactly for image cells)

### Implementation for User Story 5

- [X] T032 [US5] Implement bottom alignment in `frontend/lib/widgets/markdown_view.dart` (per-cell vertical alignment when the cell contains an image) and `backend/src/recetarios/services/pdf/base.py` (per-cell `("VALIGN", …, "BOTTOM")` style entries), applying to both book and recipe PDFs

**Checkpoint**: All five user stories independently verified

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T033 Re-run `backend/tests/perf_check.py` against the v2 books and update `specs/002-recipe-management/perf-notes.md` with a feature-003 section (SC targets unchanged)
- [X] T034 [P] Verify the e2e test `frontend/integration_test/app_test.dart` still passes on Windows (extend if the editor changed the create-book flow)
- [X] T035 [P] Update `README.md` (markdown content model, editor) and confirm CI is green on the feature branch
- [X] T036 Execute the quickstart.md manual smoke (9 steps incl. fresh-import ordering check, reset flow on an old data dir, v1 archive rejection) and append a "Validated" section to `specs/003-content-editing-ordering/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → **Foundational (Phase 2)** → everything else. Foundational is large by design: the format swap must land atomically so the app never half-works.
- **US1 (Phase 3)**: needs Foundational only. **US2 (Phase 4)**: needs Foundational only (independent of US1). **US3 (Phase 5)**: needs US1 (extends the importer). **US4 (Phase 6)** and **US5 (Phase 7)**: independent of each other and of US1–US3 (US5's renderer half builds on T012).
- **Polish (Phase 8)**: after all stories.

### Within Phase 2 (internal order)

T003 → T004 → T005 → T006/T007 → T008 → T009/T010; frontend T011 → T012/T013/T014 → T015. Backend (T003–T010) and frontend (T011–T015) tracks can run concurrently once T005 fixes the API shapes.

### File-conflict serialization

- `importer.py` is touched by T020 (US1) and T028 (US3) — keep US3 after US1.
- `markdown_view.dart` is touched by T012 (Foundational) and T032 (US5) — fine sequentially.
- `recipe_edit_form.dart` by T013 and T025 — Foundational before US2 by phase order.

### Parallel Opportunities

- T001 ∥ T002; T011/T012 ∥ backend foundational tasks (after T005); T016 ∥ T017; US2 (frontend-only) ∥ US3 (backend-only) once their phases open; T029 ∥ T031 backend half; T034 ∥ T035.

## Parallel Example: after Foundational completes

```bash
Task: "T016 Rewrite golden ordering tests (backend, US1)"
Task: "T022 Failing editor widget tests (frontend, US2)"   # different projects, both unblocked
```

## Implementation Strategy

**MVP first**: Phases 1–3. The riskiest item (appflowy_editor, US2) is intentionally NOT in the MVP: after Phase 3 the data is correct and editable through the interim markdown fields, so the feature already fixes the corruption even if the editor integration needs iteration.

**Incremental delivery**: each story phase ends shippable. Pause-and-validate points: after Phase 2 (suites green on the new model), after US1 (ordering verified against real books — the reason this feature exists), after US2 (editor UX).

**Solo order**: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8, TDD within each story.

---

## Notes

- Total: **36 tasks** (T001–T036) across 8 phases
- Existing-test rewrites are deliberate Foundational work, not test-first violations: the new failing tests for new behavior are in their story phases
- `legacy/` (v2 books) remains read-only test input
- appflowy_editor fallback (research R3): if T023 proves unworkable, the documented fallback replaces it inside the same widget contract — tasks T024–T026 are unaffected
