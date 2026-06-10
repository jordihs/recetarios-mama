# Phase 0 Research: Recipe Management

**Feature**: `002-recipe-management` | **Date**: 2026-06-10

All NEEDS CLARIFICATION items from the Technical Context are resolved below. The user mandated Flutter for the GUI and Python for the backend, Windows as the primary deliverable, with Android APK and Linux builds kept open; research therefore focuses on *how* to satisfy that mandate, not on re-litigating it.

## R1. Flutter ↔ Python integration architecture

- **Decision**: The Python backend runs as a separate local process exposing a REST API bound to `127.0.0.1` on an ephemeral port. On Windows, the Flutter app launches the bundled backend executable at startup (passing `--port 0 --data-dir <app-data>`), reads the chosen port from the process stdout handshake, supervises the process, and terminates it on exit (plus a `POST /shutdown` graceful path and a watchdog: backend exits if the parent PID disappears).
- **Rationale**: A process boundary with HTTP is the only Flutter↔Python option that is simultaneously debuggable (curl-able), testable (backend tested headlessly with pytest/httpx), and portable across desktop targets. Ephemeral port + loopback binding avoids port collisions and never exposes data on the network (offline constraint).
- **Alternatives considered**: Embedding Python in-process via FFI (fragile, per-platform CPython embedding pain); gRPC (extra codegen and binary protocol buys nothing at this scale); rewriting domain logic in Dart (violates the explicit Python-backend mandate).

## R2. Keeping Android/Linux open

- **Decision**: v1 ships Windows only. Portability is preserved contractually: the frontend talks exclusively to the REST API through one injectable `ApiClient`, and the backend is pure-Python with no Windows-only dependencies except the "open PDF" shell call, which is isolated behind a platform adapter. For Android, the documented forward path is `serious_python` (embeds a CPython runtime in a Flutter app and runs the same FastAPI service on-device); Linux desktop reuses the Windows subprocess model with a PyInstaller Linux build.
- **Rationale**: Satisfies "leave open options ... using the build tool" without paying the Android-embedding cost now (YAGNI). All platform-specific code is confined to two seams: process launch (frontend `core/`) and OS file-open (backend adapter / `open_filex` on mobile).
- **Alternatives considered**: Building the APK now (large effort, not the primary target); a cloud backend (violates offline requirement); Kivy/BeeWare all-Python UI (violates Flutter mandate).

## R3. Python web framework

- **Decision**: FastAPI + uvicorn, pydantic v2 models.
- **Rationale**: Declarative validation and OpenAPI schema for free (the contract in `contracts/rest-api.md` maps 1:1), async-capable for long PDF jobs, the de-facto stable standard for local Python APIs.
- **Alternatives considered**: Flask (manual validation, no native async); Django (server-grade weight, ORM and admin unused here).

## R4. Storage & full-text search

- **Decision**: Single SQLite database file (WAL mode) in the per-user app data directory; images stored as files in a content-addressed store (`images/<sha256>.<ext>`), referenced by hash from content blocks. Full-text search via SQLite FTS5 with `tokenize = "unicode61 remove_diacritics 2"`, indexing recipe title, ingredient text, preparation text, and introduction text in a contentless-delete FTS table kept in sync by the repository layer.
- **Rationale**: Zero-admin, single-file, transactional (atomic library replace on restore), trivially bundled, and FTS5 natively delivers the accent-/case-insensitive search required by FR-037 and the <1 s / 1,000-recipe target (SC-011). Content-addressed images deduplicate legacy imports (same photo reused across books) and make the export archive straightforward.
- **Alternatives considered**: PostgreSQL (needs a server — absurd for a single-user offline app); JSON files on disk (no transactions, no FTS, fragile partial-write behavior conflicting with FR-026/FR-028); storing images as DB blobs (bloats the DB, slows backups, no streaming).

## R5. PDF generation

- **Decision**: ReportLab (Platypus document templates) in the backend. Two builders: `BookPdfBuilder` (cover page, table of contents with indented subchapters and page numbers via ReportLab's TOC/multi-pass support, chapter introduction pages, each recipe started with a page break) and `RecipePdfBuilder` (honors include-introduction / include-images flags). A4 page size, embedded TrueType fonts with full Latin-1/Spanish glyph coverage.
- **Rationale**: Pure-Python (clean PyInstaller bundling on Windows — the decisive factor), mature pagination engine with native table-of-contents and page-numbering machinery that matches the cover/index/new-page-per-recipe requirements (FR-029/FR-030) exactly.
- **Alternatives considered**: WeasyPrint (best HTML/CSS fidelity but requires GTK/Pango native DLLs on Windows — packaging risk); fpdf2 (pure Python but TOC with page references and flowing layouts are manual); printing from Flutter (`printing` package) (would duplicate rendering logic in Dart and split PDF responsibility across both stacks).

## R6. Rich content model & editor

- **Decision**: Content is stored as an ordered list of typed JSON blocks — `heading`, `paragraph` (with inline bold/italic spans), `image` (hash ref + caption + placement), `image_group` (grid of images), `table` (header + rows; cells of text or image+caption) — mirroring the legacy TipoIntroduccion structures one-to-one. The Flutter editor is a block editor: paragraphs/headings edited with `flutter_quill` instances (or plain styled `TextField`s where formatting is not needed), plus dedicated block widgets for image, image-group/grid, and table blocks with add/move/delete controls. The same block list renders the read view and feeds the ReportLab builders.
- **Rationale**: The legacy schema is already block-structured; storing blocks (not HTML or Quill Delta) makes legacy import lossless (FR-024), keeps one canonical model for screen and PDF rendering, and confines third-party editor formats to the edit widgets. "Image positioning and grid layout" (FR-019) becomes a block attribute rather than a rich-text embedding problem.
- **Alternatives considered**: HTML storage (import/export and PDF mapping get parser-heavy; positioning semantics fuzzy); raw Quill Delta as the storage format (couples persistent data to one Flutter package's format — risky for a long-lived family archive); Markdown (cannot express grids, captioned image groups, or tables-with-image-cells faithfully).

## R7. Legacy import strategy

- **Decision**: A pure-Python `legacy_import` service parses the legacy JSON (validated against `legacy/schema/recetarios-schema.json` semantics), normalizes the schema's `oneOf` single-or-array shapes, maps RECETARIO→Book, CAPITULO→Chapter (recursing into nested CAPITULO as subchapters, preserving order), RECETA→Recipe (image, INGREDIENTES `personas`→servings, GRUPO `titulo`→group heading, PREPARACION paragraphs, NOTA→note), and INTRODUCCION elements→content blocks. Image paths (`./imgs/...` relative to the document's directory) are resolved, files copied into the content-addressed store; unresolvable images are recorded in a per-import report (Spanish) returned to the UI; the whole import runs in one DB transaction.
- **Rationale**: Direct consequence of FR-022..FR-026 and clarifications (hierarchy preserved; title collision → replace-or-keep-both choice handled via a pre-import check endpoint). Golden tests run the three real books in `legacy/` end-to-end, which is the strongest cheap guarantee of SC-002 (100% content preserved).
- **Alternatives considered**: Importing via the XML sample (explicitly documentation-only per spec assumption); lenient schema-less parsing (silently drops unknown structures — conflicts with SC-002's 100% preservation).

## R8. Library archive (backup) format

- **Decision**: A single `.recetarios` file = ZIP container with `library.json` (format version + full structured export of books/chapters/recipes/settings-independent content) and `images/` (the referenced content-addressed files). Import validates the manifest, then replaces the library atomically: restore into a staging DB + image dir, then swap — never mutating the live library until success (FR-028).
- **Rationale**: One file (FR-027), self-contained including images, inspectable with standard tools, versioned for forward compatibility, and the staging-swap pattern gives the required all-or-nothing failure behavior.
- **Alternatives considered**: Bare JSON file (cannot carry images); copying the raw SQLite file (ties the archive to internal schema versions and WAL state; not import-mergeable in future).

## R9. Frontend state & navigation

- **Decision**: Riverpod for state management; go_router with path-based routes (`/books/:bookId/chapters/:chapterId.../recipes/:recipeId`) supporting arbitrary chapter-nesting depth; repository-pattern API client built on dio.
- **Rationale**: Riverpod gives compile-safe, testable dependency injection (easy to fake the API in widget tests); go_router's declarative URLs model the book→chapter*→recipe hierarchy naturally and keep back-navigation correct on desktop and mobile.
- **Alternatives considered**: Provider (weaker compile-time safety), BLoC (more ceremony than this app's state warrants — YAGNI).

## R10. Localization & encoding

- **Decision**: Spanish-only UI via Flutter `gen-l10n` (`app_es.arb`, locale fixed to `es`); backend user-facing strings (import reports, error messages) come from a small Spanish message catalog module. UTF-8 enforced end-to-end: SQLite stores UTF-8 natively, API is JSON/UTF-8, PDF fonts embed Spanish glyphs; legacy JSON read as UTF-8.
- **Rationale**: Constitution VI (code/docs English, UI Spanish) plus FR-003/FR-004. Using the l10n pipeline now (even with one locale) keeps strings out of code, which is also a code-quality win.
- **Alternatives considered**: Hard-coded Spanish strings in widgets (scatters UI text, breaks the constitution's consistency goals).

## R11. Packaging & build (Windows-first)

- **Decision**: Backend frozen with PyInstaller (one-folder mode) into `dist/backend/`; `flutter build windows` produces the GUI; a build script assembles both into one distributable folder where the Flutter exe expects the backend at a known relative path (with a dev-mode override `RECETARIOS_BACKEND_CMD` for running from sources). Settings and data live under `%APPDATA%/recetarios-mama/` (per-platform equivalent via `platformdirs`). Default PDF output folder preset: the OS user folder (per spec assumption). PDFs are opened post-generation via `open_filex` from the Flutter side (keeping the OS-integration on the UI layer).
- **Rationale**: Matches "generate a windows app ... leave open options (android apk, linux executable) using the build tool": the same script grows `flutter build apk` / `flutter build linux` targets later; PyInstaller one-folder mode avoids the slow self-extracting one-file startup.
- **Alternatives considered**: MSIX/installer authoring now (deferred — a plain folder/zip is enough for v1); Nuitka (longer builds, no practical gain here).
