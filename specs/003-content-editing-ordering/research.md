# Phase 0 Research: Content Editing & Legacy Ordering

**Feature**: `003-content-editing-ordering` | **Date**: 2026-06-11

## R1. Markdown as canonical rich-content format

- **Decision**: Store every rich content section (book/chapter `presentation`, recipe `introduction` and `preparation`) as one **markdown TEXT** column. Dialect: CommonMark + GFM tables, nothing else. Conventions: image = `![<caption>](image://<sha256>)` (alt text is the caption); **gallery** = a paragraph consisting solely of consecutive image lines → renderers display it as a grid; **table title** = a bold line immediately above the table; emphasis (`**`/`*`), `##`/`###` headings, and `-` lists round-trip everywhere.
- **Rationale**: Mandated by the spec (clarified); standard, human-readable, diff-able, editable as source, and both ecosystems have mature parsers. One representation feeds screen, editor, PDFs, descriptions, and FTS.
- **Alternatives considered**: Keeping JSON blocks with an added order index (fixes ordering but keeps the clunky per-block editing the spec abolishes); HTML (heavier to edit as source, more parser surface).

## R2. Markdown parsing

- **Decision**: Backend: `markdown-it-py` + `mdit-py-plugins` (GFM tables) → token stream consumed by three adapters: PDF flowables, plain-text extraction (FTS + first-paragraph description), and import-time validation. Frontend rendering: `package:markdown` (Dart team) → AST → custom widget mapper `markdown_view.dart` evolved from the existing `BlockRenderer` (image:// resolution, consecutive-image grids, bottom-aligned image cells).
- **Rationale**: Both are the maintained de-facto parsers in their ecosystems with CommonMark+GFM parity, so the same document renders consistently. An AST-based custom renderer keeps full control over this app's specific visuals (grids, captions, table alignment) — the same control we had with blocks.
- **Alternatives considered**: `flutter_markdown` (archived/discontinued by the Flutter team — disqualified); `mistune` backend (fine, but markdown-it-py's plugin model matches the Dart side's GFM behavior more exactly).

## R3. Editing surface

- **Decision**: `appflowy_editor` as the WYSIWYG editing surface, wrapped in one widget (`markdown_editor.dart`) whose public contract is markdown-in/markdown-out. Toolbar: bold, italic, H2/H3, bulleted list, table, image insertion (uploads via existing `POST /images`, inserts `image://` ref). An unobtrusive "fuente" (source) toggle opens the raw markdown in a plain text area with monospace font; preview/WYSIWYG is the default. Constructs the WYSIWYG cannot represent natively (e.g., tables with image cells) appear as protected raw blocks in WYSIWYG mode and are editable through the source view — the canonical markdown is never lossy-round-tripped.
- **Rationale**: Matches the spec's "rich text editor … defaulting to the preview, with source button not prominent". appflowy_editor is actively maintained, production-proven (AppFlowy), themable, and has markdown encode/decode. Containment (single widget, markdown canonical, raw-block escape hatch) caps the dependency risk.
- **Alternatives considered**: Source-first TextField + preview toggle (fails "preview default" requirement; kept as the documented fallback if appflowy integration proves unworkable during implementation — the widget contract is identical either way); `super_editor`/`fleather` (delta-based storage formats couple data to the package; markdown conversion less direct); from-scratch WYSIWYG (cost/risk far beyond this feature).

## R4. Legacy import v2

- **Decision**: `parser.py` validates the v2 shape: every `INTRODUCCION` must be an object whose content is the ordered `CONTENIDO` array; presence of v1 markers (`PARRAFO`/`TITULO`/`IMAGEN`/`IMAGENES`/`TABLA` keys directly on the introduction object, or string introductions) → `legacy_v1_unsupported` error (Spanish). `mapper.py` walks `CONTENIDO` in order emitting markdown: `TITULO` → `##` first / `###` after; `PARRAFO` → paragraph; `IMAGEN` → image line; `IMAGENES` → consecutive image lines (gallery); `TABLA` → bold title line + GFM table (cells with images emit `![caption](image://hash)`); `NOTA` → collected into the element's `note` field (multiple notes joined as paragraphs), never into the body. Recipes: `INGREDIENTES`/`PREPARACION` optional → empty sections; `NOTA` string-or-array → joined. Whitespace cleanup and missing-image reporting behave as today.
- **Rationale**: Direct mapping of FR-001..007 onto the verified v2 schema and sample files (all three books conform; multi-title and string-intro cases checked against the real data).
- **Alternatives considered**: Auto-converting v1 grouped files (rejected in clarification — would re-introduce the scrambled ordering this feature exists to fix).

## R5. Image fallback pass

- **Decision**: After an element tree is imported, a post-pass assigns images: for the book and for each chapter lacking a valid image, take the **first** `image://` reference found in a depth-first, document-order walk of the element's own content, then its children's (chapter intros, subchapters, recipes — recipe cover then recipe content). Recipes are never assigned fallbacks. Implemented in `importer.py` over already-resolved hashes, so "valid" is guaranteed (unresolved images were dropped with a report entry).
- **Rationale**: FR-016..019 verbatim; running after resolution avoids re-checking file existence.
- **Alternatives considered**: Picking the "best" image (largest/landscape) — not requested, subjective, and violates the spec's "first found in document order".

## R6. Schema v2, no-migration reset flow, archives

- **Decision**: SQLite `user_version` → 2; `db.py` creates v2 directly on fresh data dirs. If it opens a v1 database it does NOT touch it; the app exposes `GET /library/status` → `{format: "current" | "legacy"}` and `POST /library/reset` (drops and recreates the database; content-addressed images directory is left in place — re-import reuses identical files). On `legacy` status the frontend (new `library_reset` feature) blocks the UI with a Spanish explanation and a reset button (FR-014). Archive manifest `format_version` → 2 (markdown content, note fields); importing a `format_version: 1` archive → `archive_unsupported_version` Spanish error (FR-015).
- **Rationale**: Clarified no-migration decision; keeping images is free (hashes identical) and speeds re-import.
- **Alternatives considered**: Silent auto-wipe (destroys data without consent — violates FR-014's explicit consent); supporting both schema versions side by side (permanent complexity for a one-time transition).

## R7. Display fixes

- **Decision**: `ItemCard`: when `imageUrl == null`, the description `Text` gets the card's full remaining height (maxLines computed from available space via `LayoutBuilder`, roughly doubling visible lines) — image cards keep today's exact layout. Tables: screen renderer wraps image-cell content in a bottom-aligned column (`TableCellVerticalAlignment.bottom`); ReportLab adds per-cell `("VALIGN", cell, cell, "BOTTOM")` style entries for cells that contain images (applies to both book and recipe PDFs per clarification).
- **Rationale**: FR-020/021 and SC-006/007, scoped to not disturb existing layouts.

## R8. FTS, descriptions, and PDFs over markdown

- **Decision**: One backend helper module (`models/markdown.py`) provides: `plain_text(md)` (token walk, strips syntax, keeps captions and cell text — feeds FTS), `first_paragraph(md)` (first non-heading paragraph's plain text — feeds list descriptions), `referenced_images(md)` (`image://` extraction — feeds validation, archive export, fallback pass). PDF building maps tokens → existing flowable vocabulary (headings → heading styles, gallery paragraphs → image grids, tables → Platypus tables), so PDF visual quality is unchanged except the alignment fix.
- **Rationale**: Centralizes every markdown interpretation in one tested module; FR-013's "all consumers equivalent" becomes a unit-testable property.

## R9. Test strategy deltas

- **Decision**: Golden tests re-anchored on the v2 books: per-introduction, the emitted markdown's element sequence must equal the source `CONTENIDO` sequence (machine-checked, SC-001); existing counting/preservation tests stay. New unit suites: mapper emission per block type, markdown helpers, fallback-image pass, v1 rejection (DB, archive, import). Widget tests: editor opens in preview/WYSIWYG mode with source toggle, imageless card line count, bottom-aligned table cells, reset dialog flow. Perf script re-run unchanged.
- **Rationale**: Ordering is the feature's reason to exist — it gets the machine-checkable golden guarantee.
