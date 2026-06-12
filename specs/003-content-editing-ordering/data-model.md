# Data Model: Content Editing & Legacy Ordering

**Feature**: `003-content-editing-ordering` | **Date**: 2026-06-11

Delta over feature 002's data model. Identity, hierarchy (Book → nested Chapter → Recipe), ordering (`position`), images store, ingredients structure, and settings are **unchanged**. What changes is the representation of rich content and two new note fields.

## Rich Content Document (replaces ContentBlock[])

| Where | Old | New |
|---|---|---|
| `books.presentation` | JSON block list | **markdown TEXT** (may be empty) |
| `chapters.presentation` | JSON block list | **markdown TEXT** |
| `recipes.introduction` | JSON block list | **markdown TEXT** |
| `recipes.preparation` | JSON block list | **markdown TEXT** |

**Dialect**: CommonMark + GFM tables. Conventions (enforced by emitters, tolerated loosely by renderers):

- Headings: `##` main section, `###` subsection (level 1 is reserved for the item's own title outside the document).
- Image: `![<caption>](image://<sha256>)` — alt text is the caption; the URI resolves through the existing image store.
- Gallery: a paragraph of consecutive image lines (nothing else) → rendered as a grid; in PDFs as an image-grid table.
- Table: GFM table; optional title as a `**bold**` line directly above; cells may contain an image ref plus text (text renders bottom-aligned per FR-021).
- Lists: `-` bullets. Emphasis: `*italic*`, `**bold**`.

**Derived values** (all computed by `models/markdown.py`):

- `description` (list cards) = plain text of the first non-heading paragraph.
- FTS text = full plain-text flattening (headings, paragraphs, captions, table cell text).
- `referenced_images` = set of `image://` hashes (validation on write, archive export, fallback pass).

## Note (new field on Book and Chapter)

| Field | Type | Constraints |
|-------|------|-------------|
| `books.note` | TEXT, nullable | populated from legacy `NOTA` blocks of the book introduction (multiple → joined as paragraphs); user-editable |
| `chapters.note` | TEXT, nullable | same, per chapter |
| `recipes.note` | TEXT, nullable | existing; legacy `NOTA` may now be a list → joined |

Displayed at the foot of the item's content in the recipe-note visual style. Excluded from the rich document body (FR-004). Included in FTS? — yes, appended to the FTS `introduction` column text.

## Schema version & lifecycle

- `PRAGMA user_version = 2`. Fresh databases are created at v2.
- Opening a pre-v2 database: wiped automatically on startup (database file **and** images directory deleted, schema recreated at v2). No migration, no prompt, no trace — the app behaves as a first install. *(Amended post-implementation by owner decision: the original consent-based reset flow was removed.)*
- Validation on write: markdown size sane (≤ 1 MB per document), every `image://` ref must exist in the store (same rule as before).

## SQLite schema delta (v2)

```sql
-- books.presentation, chapters.presentation: markdown TEXT NOT NULL DEFAULT ''
-- recipes.introduction, recipes.preparation: markdown TEXT NOT NULL DEFAULT ''
ALTER-equivalent: v2 CREATE TABLE statements only (no migration path; v1 DBs are reset).
ADD COLUMN books.note TEXT;
ADD COLUMN chapters.note TEXT;
-- recipe_fts unchanged in shape; its column texts now come from markdown flattening.
PRAGMA user_version = 2;
```

## Library archive format v2

```text
archive.recetarios
├── library.json     # format_version: 2; presentation/introduction/preparation as markdown strings;
│                    # note on books, chapters, recipes
└── images/          # unchanged (content-addressed)
```

- Import of `format_version: 1` → rejected (`archive_unsupported_version`, Spanish message). No conversion.

## Legacy (v2 schema) → application mapping

| Legacy v2 element (in `CONTENIDO` order) | Markdown emission |
|---|---|
| `{tipo: TITULO}` (first in intro) | `## <texto>` |
| `{tipo: TITULO}` (subsequent) | `### <texto>` |
| `{tipo: PARRAFO}` | paragraph (whitespace-normalized) |
| `{tipo: IMAGEN}` | `![caption](image://hash)` line (unresolved → dropped + report entry) |
| `{tipo: IMAGENES}` | consecutive image lines (gallery paragraph) |
| `{tipo: TABLA}` | optional `**titulo**` line + GFM table; image cells as `![text](image://hash)` |
| `{tipo: NOTA}` | → element's `note` field (joined if several); never in the body |
| `RECETA` without `INGREDIENTES`/`PREPARACION` | recipe with empty section(s) |
| `RECETA.NOTA` (string or array) | recipe `note` (joined) |

## Image fallback assignment (import-time, derived)

- Book/chapter without valid own image ← first `image://` hash from a depth-first document-order walk of: own presentation → (for chapters) own recipes (cover, then content) and subchapters; (for books) chapters in order.
- Recipes: never assigned.
- Stored in the existing `cover_image` / `image` columns — no new field; nothing distinguishes a fallback from an authored image afterwards (user can change it like any other).

## Frontend DTO changes (`data/models.dart`)

- `BookDetail.presentation`, `ChapterDetail.presentation`: `String` (markdown) + new `note: String?`.
- `Recipe.introduction`, `Recipe.preparation`: `String` (markdown); `ingredients` unchanged (structured).
- `ItemSummary` unchanged (description remains a server-derived plain string).
- `ContentBlock` typedef and block helpers removed.
