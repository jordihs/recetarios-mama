# REST API Contract: Recipe Management Backend

**Feature**: `002-recipe-management` | **Date**: 2026-06-10

Local-only API: bound to `127.0.0.1`, ephemeral port chosen at startup (`--port 0`), announced on stdout as `RECETARIOS_PORT=<n>`. JSON bodies, UTF-8. FastAPI serves the generated OpenAPI document at `/openapi.json` — this file is the human-readable contract the frontend codes against; field shapes follow `data-model.md`.

Errors: non-2xx responses use `{ "error": { "code": string, "message": string } }` where `message` is user-presentable Spanish and `code` is a stable machine key (English).

## Lifecycle

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /health` | Readiness probe | `200 {"status":"ok","version":...}`; frontend polls during startup |
| `POST /shutdown` | Graceful stop | Frontend calls on exit; backend also self-terminates if parent process dies |

## Books

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /books` | List books in position order | Items include `id, title, cover_image, description` (derived first-paragraph text) |
| `POST /books` | Create book | Body: `title`, optional `cover_image`, `presentation`; appended at end (FR-007/008) |
| `GET /books/{id}` | Full book (incl. `presentation`) | |
| `PUT /books/{id}` | Update title/cover/presentation | |
| `DELETE /books/{id}` | Cascade delete | UI confirms beforehand |
| `PUT /books/order` | Reorder books | Body: `{"ids": [...]}` complete permutation |

## Chapters

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /books/{bookId}/chapters?parent={chapterId\|null}` | List sibling chapters at one nesting level, position order | Items include `id, title, cover_image, description, has_subchapters, recipe_count` |
| `POST /books/{bookId}/chapters` | Create chapter | Body incl. optional `parent_chapter_id` (FR-010/011/011a) |
| `GET /chapters/{id}` | Full chapter | |
| `PUT /chapters/{id}` | Update | Re-parenting validated: same book, no cycles |
| `DELETE /chapters/{id}` | Cascade delete (subchapters + recipes) | |
| `PUT /chapters/order` | Reorder siblings | Body: `{"parent": bookId/chapterId, "ids": [...]}` (FR-011b) |

## Recipes

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /chapters/{chapterId}/recipes` | List recipes, position order | Items: `id, title, image, description` (intro first paragraph); titles-only display is a UI mode, same payload (FR-012/013) |
| `POST /chapters/{chapterId}/recipes` | Create recipe | Full recipe body (FR-020) |
| `GET /recipes/{id}` | Full recipe (intro, ingredients, preparation, note) | View order is a UI concern (FR-014) |
| `PUT /recipes/{id}` | Whole-recipe atomic update (save in edit mode, FR-018) | |
| `DELETE /recipes/{id}` | Delete | |
| `PUT /recipes/order` | Reorder within chapter | `{"chapter_id": ..., "ids": [...]}` |

## Images

| Method & Path | Purpose | Notes |
|---|---|---|
| `POST /images` | Ingest image (multipart upload) | Returns `{ "hash", "ext", "width", "height" }`; dedupes by content hash |
| `GET /images/{hash}` | Serve image bytes | Used by Flutter `Image.network` against localhost; cacheable (immutable) |

## Search

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /search?q={text}` | Full-text search, accent/case-insensitive (FR-036/037) | Returns ranked `[{ "recipe_id", "title", "breadcrumb": [{type,id,title}...], "snippet" }]` (FR-038) |

## Legacy import

| Method & Path | Purpose | Notes |
|---|---|---|
| `POST /import/legacy/inspect` | Pre-flight: body `{"path": <json file>}` | Returns `{ "book_title", "collision": bool }` so the UI can offer replace / keep-both (FR-022a) |
| `POST /import/legacy` | Execute import | Body `{"path": ..., "on_collision": "replace" \| "keep_both"}`; runs in one transaction; returns `{ "book_id", "report": { "chapters": n, "recipes": n, "images_imported": n, "images_missing": [paths] } }` (FR-022..026) |

## Library export / import (backup)

| Method & Path | Purpose | Notes |
|---|---|---|
| `POST /library/export` | Body `{"path": <target .recetarios>}` | Writes ZIP archive (FR-027) |
| `POST /library/import` | Body `{"path": ..., "confirm_replace": true}` | Full replace, staging + atomic swap; rejects without `confirm_replace` (FR-028) |

## PDF generation

| Method & Path | Purpose | Notes |
|---|---|---|
| `POST /pdf/book/{bookId}` | Body `{"output_dir"?: path}` (defaults to setting) | Cover + indented index + chapter intro pages + recipes each on a new page (FR-029/030); returns `{ "path" }`; UI opens it (FR-034) |
| `POST /pdf/recipe/{recipeId}` | Body `{"include_introduction": bool, "include_images": bool, "output_dir"?: path}` | FR-031..033; returns `{ "path" }` |

Long-running book PDFs report progress via simple polling: the POST returns `{ "job_id" }` when generation exceeds ~1 s, with `GET /pdf/jobs/{job_id}` → `{ "status": "running"\|"done"\|"error", "path"?, "error"? }` (keeps UI responsive for SC-005-scale books; recipe PDFs are synchronous).

## Settings

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /settings` | All settings | `{ "pdf_output_dir": ... }` (FR-035) |
| `PUT /settings` | Update | Validates the directory exists/is writable; persists across restarts |

## Contract conventions

- All list orders are `position`-based; reorder endpoints take full sibling permutations to avoid partial-order ambiguity.
- Mutation endpoints are atomic; any failure leaves prior state intact (aligned with FR-026/FR-028).
- The frontend never touches the filesystem for library data — only paths it owns (import source picker, export target, PDF output) cross the API as strings chosen via OS dialogs.
