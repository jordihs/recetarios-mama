# Tasks: Recipe Management

**Input**: Design documents from `/specs/002-recipe-management/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/rest-api.md, quickstart.md

**Tests**: Included — the project constitution (Principle II, Testing Excellence) makes test coverage non-negotiable and prefers TDD. Test tasks are written FIRST and must FAIL before the implementation tasks that make them pass.

**Organization**: Tasks are grouped by user story (US1–US9 from spec.md) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1…US9)
- Exact file paths included in every description

## Path Conventions

Two projects per plan.md: `backend/` (Python 3.12, FastAPI, package `recetarios` under `backend/src/`) and `frontend/` (Flutter 3.x). Build scripts under `build/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Both project skeletons exist, tooling runs, repo builds from a clean checkout

- [X] T001 Create backend project skeleton: `backend/pyproject.toml` (project `recetarios`, deps fastapi, uvicorn, pydantic, reportlab, pillow, platformdirs; dev deps pytest, httpx, ruff, pypdf), package dirs `backend/src/recetarios/{api,models,services,services/pdf,storage,l10n}/__init__.py`, test dirs `backend/tests/{unit,integration,golden}/`
- [X] T002 [P] Create Flutter project in `frontend/` (`flutter create --platforms=windows,android,linux`), add dependencies to `frontend/pubspec.yaml`: riverpod/flutter_riverpod, go_router, dio, flutter_quill, file_selector, open_filex, flutter_localizations; create dirs `frontend/lib/{app,core,data,features,widgets}/`
- [X] T003 [P] Configure backend tooling: ruff + pytest settings in `backend/pyproject.toml`, `backend/tests/conftest.py` with tmp data-dir + TestClient app fixture
- [X] T004 [P] Configure frontend tooling: `frontend/analysis_options.yaml` (flutter_lints), `frontend/l10n.yaml` + initial `frontend/l10n/app_es.arb` (Spanish-only locale wiring)
- [X] T005 [P] Create build script skeletons `build/build-windows.ps1` and `backend/recetarios.spec` (PyInstaller one-folder) with TODO assembly steps documented from research R11
- [X] T081 [P] Create CI pipeline in `.github/workflows/ci.yml`: backend job (`ruff check`, `pytest`) + frontend job (`flutter analyze`, `flutter test`) on push/PR — constitution Quality Gates mandate (task added by /speckit-analyze remediation, hence out-of-sequence ID)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Storage, API lifecycle, image pipeline, app shell, and API client — everything every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Implement SQLite layer in `backend/src/recetarios/storage/db.py`: connection factory (WAL, foreign_keys ON, UTF-8), schema creation per data-model.md (books, chapters, recipes, images, settings, recipe_fts virtual table), `user_version` migration hook
- [X] T007 [P] Implement pydantic models in `backend/src/recetarios/models/` (`blocks.py`: discriminated ContentBlock union heading/paragraph/image/image_group/table + Cell + spans; `entities.py`: Book, Chapter, Recipe, IngredientsList/Group with constraints from data-model.md)
- [X] T008 [P] Implement content-addressed image store in `backend/src/recetarios/storage/images.py`: ingest bytes → sha256 + ext + dimensions (Pillow), dedupe, serve path lookup, referenced-hash listing for GC/export
- [X] T009 Implement FastAPI app factory in `backend/src/recetarios/api/app.py`: router registration, `{error:{code,message}}` exception handlers, and Spanish user-facing message catalog in `backend/src/recetarios/l10n/messages.py`
- [X] T010 Implement process lifecycle in `backend/src/recetarios/__main__.py`: `--port` (0 = ephemeral, print `RECETARIOS_PORT=<n>` handshake), `--data-dir` (default via platformdirs), bind 127.0.0.1 only, `GET /health`, `POST /shutdown`, parent-PID watchdog
- [X] T011 Implement image endpoints `POST /images` (multipart) and `GET /images/{hash}` in `backend/src/recetarios/api/images.py` with integration tests in `backend/tests/integration/test_images_api.py`
- [X] T012 [P] Implement Flutter app shell in `frontend/lib/app/`: MaterialApp.router with Material 3 theme, fixed `es` locale + gen-l10n setup, go_router skeleton with routes `/books`, `/books/:bookId`, chapter-path and recipe routes per research R9
- [X] T013 [P] Implement backend launcher/supervisor in `frontend/lib/core/backend_launcher.dart`: honor `RECETARIOS_BACKEND_URL` (attach) and `RECETARIOS_BACKEND_CMD` (spawn dev), packaged relative-path spawn, stdout port handshake parse, /health polling, kill on app exit
- [X] T014 Implement API client base in `frontend/lib/data/api_client.dart`: dio instance bound to resolved base URL, JSON/UTF-8, error envelope → typed `ApiException` with Spanish message passthrough
- [X] T015 [P] Implement shared UI primitives in `frontend/lib/widgets/`: `item_card.dart` (title + optional image + ellipsis-truncated description, responsive grid sizing) and `block_renderer.dart` (read-only rendering of all 5 ContentBlock types incl. right-float image and grid image_group)

**Checkpoint**: Backend starts, handshakes, serves /health and images; Flutter shell boots against it — user story implementation can now begin

---

## Phase 3: User Story 1 - Book Browsing & Management (Priority: P1) 🎯 MVP

**Goal**: Open the app → see all books (title, cover, ellipsis description) in a responsive layout; create, edit, delete books

**Independent Test**: Launch app, observe book list, create a book via the form, edit it, delete it with confirmation; resize window phone→desktop and verify layout adapts (spec US1 acceptance scenarios)

### Tests for User Story 1 (write first, must fail) ⚠️

- [X] T016 [P] [US1] Write failing API tests for books CRUD + reorder + derived `description` extraction in `backend/tests/integration/test_books_api.py` (covers `GET/POST /books`, `GET/PUT/DELETE /books/{id}`, `PUT /books/order`, cascade delete per contract)

### Implementation for User Story 1

- [X] T017 [US1] Implement book persistence (CRUD, dense `position` management, cascade delete, reorder permutation) in `backend/src/recetarios/storage/repository.py`
- [X] T018 [US1] Implement library service for books in `backend/src/recetarios/services/library.py`: validation (non-empty title ≤200), first-paragraph description derivation, image-hash existence checks
- [X] T019 [US1] Implement books router in `backend/src/recetarios/api/books.py` wiring contract endpoints to the service (T016 tests go green)
- [X] T020 [P] [US1] Implement Book DTO + repository in `frontend/lib/data/books_repository.dart` (list/get/create/update/delete/reorder against API client)
- [X] T021 [US1] Implement book list screen in `frontend/lib/features/books/book_list_screen.dart`: responsive grid of item cards, "Añadir libro" button, reorder (move up/down) actions, empty state (FR-006/007, FR-011b)
- [X] T022 [US1] Implement book create/edit form in `frontend/lib/features/books/book_form_screen.dart`: title, cover image pick + upload via `POST /images`, description paragraph text (stored as first presentation block)
- [X] T023 [US1] Implement book deletion flow with Spanish cascade-confirmation dialog in `frontend/lib/features/books/book_actions.dart`
- [X] T024 [P] [US1] Write widget tests for book card truncation, responsive grid, and form validation in `frontend/test/features/books/book_list_test.dart`

**Checkpoint**: Book management fully functional and demoable — MVP

---

## Phase 4: User Story 2 - Chapter Browsing & Management (Priority: P2)

**Goal**: Inside a book, browse/create/edit/delete chapters at any nesting level with the same card pattern

**Independent Test**: Select a book, see chapter list, create a chapter and a subchapter inside it, navigate into nesting levels, delete with confirmation (spec US2 scenarios incl. 5–6)

### Tests for User Story 2 (write first, must fail) ⚠️

- [X] T025 [P] [US2] Write failing API tests for chapters in `backend/tests/integration/test_chapters_api.py`: sibling listing by `parent`, nesting create, re-parent validation (same book, cycle rejection), reorder, cascade delete, `has_subchapters`/`recipe_count` fields

### Implementation for User Story 2

- [X] T026 [US2] Implement chapter persistence (sibling queries, recursive cascade, position per parent) in `backend/src/recetarios/storage/repository.py`
- [X] T027 [US2] Implement chapter service rules (same-book parent, cycle prevention, depth info) in `backend/src/recetarios/services/library.py`
- [X] T028 [US2] Implement chapters router in `backend/src/recetarios/api/chapters.py` per contract (T025 green)
- [X] T029 [P] [US2] Implement Chapter DTO + repository in `frontend/lib/data/chapters_repository.dart`
- [X] T030 [US2] Implement chapter list screen (recursive route for nesting, breadcrumb AppBar, subchapters + recipes sections, "Añadir capítulo" at current level, empty state, reorder, delete-chapter action with Spanish cascade-confirmation dialog) in `frontend/lib/features/chapters/chapter_list_screen.dart`
- [X] T031 [US2] Implement chapter create/edit form (title, image, description; parent fixed by navigation context) in `frontend/lib/features/chapters/chapter_form_screen.dart`
- [X] T032 [P] [US2] Write widget tests for nested navigation and empty states in `frontend/test/features/chapters/chapter_list_test.dart`

**Checkpoint**: Books + chapters (nested) independently testable

---

## Phase 5: User Story 3 - Recipe Browsing & Viewing (Priority: P3)

**Goal**: Browse a chapter's recipes (detailed cards or titles-only toggle) and read a recipe in view mode: introduction → ingredients → preparation

**Independent Test**: In a chapter with recipes, toggle display modes, open a recipe, verify section order, grouped ingredients with servings, read-only initial state (spec US3 scenarios)

### Tests for User Story 3 (write first, must fail) ⚠️

- [X] T033 [P] [US3] Write failing API tests for recipe read endpoints in `backend/tests/integration/test_recipes_api.py`: `GET /chapters/{id}/recipes` summaries (id, title, image, description), `GET /recipes/{id}` full payload, position ordering

### Implementation for User Story 3

- [X] T034 [US3] Implement recipe read persistence (summaries with intro-derived description, full fetch) in `backend/src/recetarios/storage/repository.py`
- [X] T035 [US3] Implement recipes router read endpoints + reorder endpoint in `backend/src/recetarios/api/recipes.py` (T033 green)
- [X] T036 [P] [US3] Implement Recipe DTOs (full content-block + ingredients shapes) and repository in `frontend/lib/data/recipes_repository.dart`
- [X] T037 [US3] Implement recipe list screen with detailed/titles-only toggle control and reorder in `frontend/lib/features/recipes/recipe_list_screen.dart` (FR-012/013)
- [X] T038 [US3] Implement recipe view screen in `frontend/lib/features/recipes/recipe_view_screen.dart`: block-rendered introduction, ingredients (groups, headings, servings), block-rendered preparation, note footer; opens read-only (FR-014..016)
- [X] T039 [P] [US3] Write widget tests for display-mode toggle and section order in `frontend/test/features/recipes/recipe_view_test.dart`

**Checkpoint**: Full browse-and-read journey works end to end

---

## Phase 6: User Story 4 - Recipe Creation & Editing (Priority: P4)

**Goal**: Edit mode with save/discard; rich block editor (text + positioned images + grid) for introduction/preparation; list editor for ingredients; create new recipes

**Independent Test**: Edit a recipe (title, ingredient, paragraph, insert image), save, reload, verify persisted; repeat with discard, verify unchanged; create a recipe from the list (spec US4 scenarios)

### Tests for User Story 4 (write first, must fail) ⚠️

- [X] T040 [P] [US4] Write failing API tests for recipe writes in `backend/tests/integration/test_recipes_write_api.py`: `POST /chapters/{id}/recipes`, atomic `PUT /recipes/{id}`, `DELETE /recipes/{id}`, validation failures (unknown block type, missing image hash, empty title)

### Implementation for User Story 4

- [X] T041 [US4] Implement recipe write service (whole-recipe atomic update, block + image-ref validation) in `backend/src/recetarios/services/library.py`
- [X] T042 [US4] Implement recipe write endpoints in `backend/src/recetarios/api/recipes.py` (T040 green)
- [X] T043 [US4] Implement content block editor in `frontend/lib/widgets/block_editor/`: block list with add/move/delete; flutter_quill-based paragraph/heading editing; image block (upload, caption, placement right/block); image_group with grid layout; table editor (FR-019)
- [X] T044 [US4] Implement ingredients list editor (groups with optional headings, add/remove/reorder items, servings field) in `frontend/lib/features/recipes/ingredients_editor.dart`
- [X] T045 [US4] Implement recipe edit mode in `frontend/lib/features/recipes/recipe_edit_screen.dart`: view↔edit toggle, "Guardar"/"Descartar cambios" buttons, local draft state, unsaved-changes navigation guard (FR-017/018/021)
- [X] T046 [US4] Implement "Añadir receta" creation flow and recipe deletion with Spanish confirmation dialog from the recipe list/view in `frontend/lib/features/recipes/recipe_actions.dart` (FR-020)
- [X] T047 [US4] Upgrade book and chapter forms to use the block editor for full presentation content in `frontend/lib/features/books/book_form_screen.dart` and `frontend/lib/features/chapters/chapter_form_screen.dart` (FR-008/011)
- [X] T048 [P] [US4] Write widget tests for save/discard semantics and editor block operations in `frontend/test/features/recipes/recipe_edit_test.dart`

**Checkpoint**: Full content lifecycle (create/read/update/delete) for all entity types

---

## Phase 7: User Story 5 - Legacy Data Import (Priority: P5)

**Goal**: Import a legacy JSON book (whole hierarchy, ingredients groups, intro blocks, tables, images via `./imgs` relative paths) with collision choice and Spanish report

**Independent Test**: Import `legacy/recetas_de_mama.json` and the two "setas" books; verify chapters (incl. nesting), recipes, groups, tables, images all present; verify missing-image reporting and replace/keep-both collision flow (spec US5 scenarios, SC-002)

### Tests for User Story 5 (write first, must fail) ⚠️

- [X] T049 [P] [US5] Write failing golden tests in `backend/tests/golden/test_legacy_import.py`: import all three real books from `legacy/`, assert book/chapter/recipe counts, nested-chapter preservation, sample ingredient groups + servings, table blocks, image ingestion counts, missing-image report entries
- [X] T050 [P] [US5] Write failing unit tests for shape normalization (string-or-array PARRAFO/PREPARACION/CAPITULO/RECETA/GRUPO, IMAGEN vs IMAGENES) in `backend/tests/unit/test_legacy_parser.py`

### Implementation for User Story 5

- [X] T051 [US5] Implement legacy parser/normalizer (read UTF-8 JSON, normalize all `oneOf` single-vs-array shapes into canonical lists) in `backend/src/recetarios/services/legacy_import/parser.py`
- [X] T052 [US5] Implement legacy→model mapper per data-model.md mapping table (RECETARIO→Book, recursive CAPITULO→Chapter, RECETA→Recipe, INTRODUCCION elements→content blocks, root recipes→auto chapter) in `backend/src/recetarios/services/legacy_import/mapper.py`
- [X] T053 [US5] Implement importer orchestration in `backend/src/recetarios/services/legacy_import/importer.py`: resolve `./imgs` paths relative to source document, copy into image store, missing-image report (Spanish), single transaction, `on_collision` replace/keep_both handling (FR-022a/026)
- [X] T054 [US5] Implement `POST /import/legacy/inspect` and `POST /import/legacy` in `backend/src/recetarios/api/transfer.py` (T049/T050 green)
- [X] T055 [US5] Implement frontend import flow in `frontend/lib/features/transfer/legacy_import_flow.dart`: file picker, collision dialog (Reemplazar / Conservar ambos / Cancelar), import report display in Spanish

**Checkpoint**: The real family collection loads into the app — SC-002 verifiable

---

## Phase 8: User Story 6 - Book Export to PDF (Priority: P6)

**Goal**: One-click book PDF: cover page, indented index with page numbers, chapter introduction pages, each recipe on a new page, A4 print-ready

**Independent Test**: Export an imported book; inspect PDF for cover, index (subchapters indented), chapter intros, new-page-per-recipe (spec US6 scenarios, SC-005)

### Tests for User Story 6 (write first, must fail) ⚠️

- [X] T056 [P] [US6] Write failing integration test in `backend/tests/integration/test_book_pdf.py`: generate book PDF from a fixture library, assert file exists, page count > chapters+recipes, cover/TOC text present and each recipe title starts a page (extract text via pypdf)

### Implementation for User Story 6

- [X] T057 [US6] Implement PDF foundation in `backend/src/recetarios/services/pdf/base.py`: embedded TrueType fonts with Spanish glyphs, A4 styles, ContentBlock→Platypus flowable converters (paragraph spans, captioned images, grid image groups, tables)
- [X] T058 [US6] Implement `BookPdfBuilder` in `backend/src/recetarios/services/pdf/book_builder.py`: cover page (title + cover image), multi-pass TOC with indentation per nesting level and page numbers, chapter introduction pages, `PageBreak` before every recipe (FR-029/030)
- [X] T059 [US6] Implement PDF endpoints + async job polling (`POST /pdf/book/{id}`, `GET /pdf/jobs/{job_id}`) in `backend/src/recetarios/api/pdf.py` (T056 green)
- [X] T060 [US6] Implement frontend book-export action with progress dialog and auto-open via open_filex in `frontend/lib/features/books/export_book_pdf.dart` (FR-034)

**Checkpoint**: Printable family book achieved

---

## Phase 9: User Story 7 - Single Recipe Print to PDF + Settings (Priority: P7)

**Goal**: Print button on recipe view with include/skip introduction & images choices; PDF saved to persistently configurable folder and opened automatically

**Independent Test**: Print a recipe skipping images → PDF without images appears in configured folder and opens; cancel produces nothing; change default folder in settings, restart, verify persisted (spec US7 scenarios)

### Tests for User Story 7 (write first, must fail) ⚠️

- [X] T061 [P] [US7] Write failing tests in `backend/tests/integration/test_recipe_pdf.py` (all four include/skip flag combinations affect output text/images; output lands in requested dir) and `backend/tests/integration/test_settings_api.py` (`GET/PUT /settings`, dir validation, persistence across app factory restart)

### Implementation for User Story 7

- [X] T062 [US7] Implement `RecipePdfBuilder` honoring `include_introduction`/`include_images` in `backend/src/recetarios/services/pdf/recipe_builder.py` (FR-031/032)
- [X] T063 [US7] Implement settings persistence + `GET/PUT /settings` (writable-dir validation, default = OS user folder) and `POST /pdf/recipe/{id}` endpoint in `backend/src/recetarios/api/settings.py` and `backend/src/recetarios/api/pdf.py` (T061 green; FR-033/035)
- [X] T064 [US7] Implement print dialog (Incluir introducción / Incluir imágenes / Cancelar) + generate + open flow in `frontend/lib/features/recipes/print_dialog.dart`
- [X] T065 [US7] Implement settings screen with folder picker bound to `pdf_output_dir` in `frontend/lib/features/settings/settings_screen.dart`

**Checkpoint**: Kitchen-copy printing complete; configuration menu exists

---

## Phase 10: User Story 8 - Full Library Backup & Restore (Priority: P8)

**Goal**: Export entire library to one `.recetarios` ZIP (manifest + images); import replaces the library atomically after explicit confirmation

**Independent Test**: Export library → import into a clean data dir → verify 100% identical content; verify import without confirmation is rejected and failed import leaves data untouched (spec US8 scenarios, SC-007)

### Tests for User Story 8 (write first, must fail) ⚠️

- [X] T066 [P] [US8] Write failing round-trip test in `backend/tests/integration/test_library_archive.py`: export populated library, import into fresh data dir, deep-compare trees + image hashes; assert rejection without `confirm_replace`; assert corrupt archive leaves existing library intact

### Implementation for User Story 8

- [X] T067 [US8] Implement archive export (versioned `library.json` manifest + referenced images into ZIP, deterministic ordering) in `backend/src/recetarios/services/archive.py` (FR-027)
- [X] T068 [US8] Implement archive import with staging DB/images + atomic swap in `backend/src/recetarios/services/archive.py` (FR-028)
- [X] T069 [US8] Implement `POST /library/export` and `POST /library/import` in `backend/src/recetarios/api/transfer.py` (T066 green)
- [X] T070 [US8] Implement frontend export/import flows with save/open pickers and Spanish full-replace confirmation dialog in `frontend/lib/features/transfer/library_transfer_flow.dart`

**Checkpoint**: Data lifecycle closed — backup, move, restore

---

## Phase 11: User Story 9 - Full-Text Recipe Search (Priority: P9)

**Goal**: Accent/case-insensitive full-text search across titles, ingredients, preparation, and introductions, with breadcrumb results navigating to the recipe

**Independent Test**: Search "champinon" matches "champiñón" in any field; result shows book/chapter breadcrumb; selecting opens the recipe; no-match shows Spanish empty state (spec US9 scenarios, SC-011)

### Tests for User Story 9 (write first, must fail) ⚠️

- [X] T071 [P] [US9] Write failing tests in `backend/tests/integration/test_search_api.py`: accent-insensitive and case-insensitive matches per indexed field, breadcrumb correctness for nested chapters, FTS stays in sync after recipe update/delete and after legacy import

### Implementation for User Story 9

- [X] T072 [US9] Implement FTS sync in `backend/src/recetarios/storage/repository.py`: plain-text extraction from blocks/ingredients, upsert/delete FTS rows on every recipe write, full rebuild hook used by import/restore
- [X] T073 [US9] Implement search service (bm25 ranking, snippet, breadcrumb assembly) and `GET /search` in `backend/src/recetarios/api/search.py` (T071 green; FR-036..038)
- [X] T074 [US9] Implement search UI (search field in book list AppBar, results screen with breadcrumbs, navigation to recipe view, empty state) in `frontend/lib/features/search/search_screen.dart`

**Checkpoint**: All nine user stories independently functional

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Packaging, end-to-end validation, performance and quality gates

- [X] T075 [P] Write end-to-end integration test of the core journey (launch → import legacy book → browse → edit → search) in `frontend/integration_test/app_test.dart`
- [X] T076 Complete Windows packaging in `build/build-windows.ps1`: PyInstaller backend build, `flutter build windows`, assemble `dist/recetarios-mama/`, verify packaged app launches and finds bundled backend (research R11)
- [X] T077 [P] Validate performance against SC-005/006/009/011 with the imported real library (script + results note in `specs/002-recipe-management/perf-notes.md`); fix regressions found
- [X] T078 [P] Accessibility pass on frontend (semantic labels on toggles/buttons, focus order, contrast per WCAG 2.1 — constitution Quality Gates) across `frontend/lib/features/`
- [X] T079 [P] Write project `README.md` (architecture overview, dev setup pointer to quickstart, build instructions)
- [X] T080 Execute quickstart.md manual smoke checklist end-to-end on the packaged Windows build and record results in `specs/002-recipe-management/quickstart.md` (append a "Validated" section)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories. Internal order: T006→T007/T008 parallel→T009→T010/T011; frontend T012/T013 parallel→T014→T015
- **User Stories (Phases 3–11)**: All depend on Phase 2. Sequential by priority for a solo developer; stories touching disjoint files can proceed in parallel (see below)
- **Polish (Phase 12)**: T075/T077 need US1–US5+US9; T076 needs any runnable build (can start after US1); T080 needs everything

### User Story Dependencies

- **US1 (books)**: Only Foundational — MVP
- **US2 (chapters)**: Foundational + navigation from US1 screens (data layer independent)
- **US3 (recipes read)**: Foundational + US2 (recipes live in chapters)
- **US4 (recipes write)**: US3 (extends view with edit mode); T047 touches US1/US2 form files
- **US5 (legacy import)**: Data structures from US1–US4 models/repository; UI entry point independent
- **US6 (book PDF)**: Content model + repository (US1–US3); richest with US5 data
- **US7 (recipe PDF + settings)**: Shares PDF base (T057) with US6 — do T057 before T062 if US7 is taken first
- **US8 (archive)**: Repository + image store (Foundational, US1–US4 shapes)
- **US9 (search)**: Recipe write paths (US4) and import rebuild hook (US5) for full coverage; core works after US3

### Within Each User Story

- Test tasks first and failing → repository/models → services → endpoints → frontend data → frontend screens → widget tests
- Backend tasks T017/T026/T034/T072 all modify `backend/src/recetarios/storage/repository.py` — do not parallelize across stories; same for `services/library.py` (T018/T027/T041)

### Parallel Opportunities

- Phase 1: T002–T005 and T081 all [P] after T001
- Phase 2: T007+T008 together; T012+T013+T015 together while backend tasks proceed (different projects)
- Every story: its backend test task [P] with the previous story's frontend tasks
- Within stories: backend implementation and frontend DTO/repository tasks (e.g., T017–T019 vs T020) are in different projects and can run concurrently once the contract is fixed
- US6 and US8 touch disjoint backend services (`pdf/` vs `archive.py`) — parallelizable after US5

## Parallel Example: User Story 1

```bash
# After Phase 2, kick off in parallel:
Task: "T016 Write failing API tests for books CRUD in backend/tests/integration/test_books_api.py"
Task: "T020 Implement Book DTO + repository in frontend/lib/data/books_repository.dart"   # contract is fixed, no need to wait

# Then backend chain T017 → T018 → T019 while frontend builds T021 → T022 → T023
# Finish with parallel test tasks:
Task: "T024 Widget tests in frontend/test/features/books/book_list_test.dart"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 (Setup) → Phase 2 (Foundational — the long pole: process lifecycle + storage + shell)
2. Phase 3 (US1 books) → **STOP and VALIDATE**: create/browse/edit/delete books on Windows, responsive check
3. Demo: a working offline Spanish app managing books

### Incremental Delivery

Each subsequent phase is a shippable increment: +US2 chapters → +US3 reading (first real daily value) → +US4 editing → +US5 import (the family collection arrives) → +US6 printed book (headline goal) → +US7 kitchen prints → +US8 backups → +US9 search → polish & package.

### Solo-Developer Order

Follow phases 1→12 sequentially; within each story run the backend test task first (TDD), then backend impl, then frontend. The two checkpoints that most deserve a pause-and-validate are after US5 (real data imported — SC-002) and US6 (printed book — the project's reason to exist).

---

## Notes

- Total: **81 tasks** (T001–T081; T081 lives in Phase 1 Setup) across 12 phases
- [P] tasks = different files, no dependencies on incomplete tasks
- Every user story phase ends at an independently testable checkpoint mapped to spec acceptance scenarios
- Verify each story's tests fail before implementing; commit after each task or logical group
- The real `legacy/` directory is read-only test input — never modify it
