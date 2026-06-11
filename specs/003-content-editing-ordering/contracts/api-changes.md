# REST API Changes: Content Editing & Legacy Ordering

**Feature**: `003-content-editing-ordering` | **Date**: 2026-06-11
**Base contract**: `specs/002-recipe-management/contracts/rest-api.md` — everything not listed here is unchanged (paths, lifecycle, images, search, reorder, settings, PDF jobs).

## Changed payload shapes (breaking, internal API)

Rich content fields change from block arrays to **markdown strings**; books and chapters gain `note`.

| Endpoint | Field changes |
|---|---|
| `GET/POST/PUT /books`, `/books/{id}` | `presentation`: `string` (markdown, default `""`); NEW `note`: `string \| null` |
| `GET/POST/PUT` chapter endpoints | `presentation`: `string`; NEW `note`: `string \| null` |
| `GET/POST/PUT` recipe endpoints | `introduction`: `string`, `preparation`: `string`; `ingredients` unchanged (structured); `note` unchanged |
| List summaries (books/chapters/recipes) | unchanged (`description` remains derived plain text — now from markdown) |

Validation on write: every `image://<hash>` referenced in a markdown field must exist in the image store (`invalid_image_ref` otherwise); documents ≤ 1 MB (`validation_error`).

## New endpoints

| Method & Path | Purpose | Notes |
|---|---|---|
| `GET /library/status` | Detect pre-v2 libraries | `{ "format": "current" \| "legacy" }`; frontend calls it at startup |
| `POST /library/reset` | Reset an old-format library | Body `{ "confirm": true }` required; drops and recreates the database at schema v2 (images dir preserved); rejects without confirm (`reset_confirm_required`) |

## Changed behaviors

| Endpoint | Change |
|---|---|
| `POST /import/legacy` / `.../inspect` | Accepts only schema v2 (`CONTENIDO` arrays). v1-shaped documents → `400 legacy_v1_unsupported` (Spanish message). Import report unchanged in shape; image fallback assignment happens transparently |
| `POST /library/import` | Archives with `format_version != 2` → `400 archive_unsupported_version`; v2 archives carry markdown + note fields |
| `POST /library/export` | Emits `format_version: 2` |
| All endpoints on a legacy-format database | Return `409 library_format_legacy` (Spanish message directing to the reset flow), except `/health`, `/library/status`, `/library/reset` |

## New error codes (Spanish messages in `l10n/messages.py`)

- `legacy_v1_unsupported` — legacy file uses the obsolete grouped format
- `archive_unsupported_version` — backup archive predates the current format
- `library_format_legacy` — library was created with a previous version; reset required
- `reset_confirm_required` — reset must be explicitly confirmed
