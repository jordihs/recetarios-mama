# Plan: Dart Local Data Layer (Option C)

Replace the Python FastAPI backend with a direct Dart/sqflite data layer.
All platforms (Windows, Android, iOS, Linux) use the same implementation.
The Python backend is deleted entirely — no parallel operation.

## Goals

- App runs standalone on every platform with no external process
- Existing `recetarios.db` database opens without any data migration
- Existing `.recetarios` archive files remain importable
- Android APK produced alongside Windows installer in every release
- `biblioteca.recetarios` (user's live dataset) is fully preserved

---

## New Flutter packages

| Package | Purpose |
|---|---|
| `sqflite: ^2.4` | SQLite on Android / iOS |
| `sqflite_common_ffi: ^2.3` | SQLite on Windows / Linux / macOS via FFI |
| `path_provider: ^2.1` | Cross-platform app data directory |
| `crypto: ^3.0` | SHA-256 for image content-addressing |
| `pdf: ^3.13` | PDF generation |
| `printing: ^5.13` | Save / share / print PDFs |
| `archive: ^4.0` | ZIP read/write for `.recetarios` files |

Remove `dio` (no HTTP needed).

---

## Data directory compatibility (critical)

The Python backend stored data via `platformdirs.user_data_dir("recetarios-mama", appauthor=False)`:

| Platform | Path |
|---|---|
| Windows | `%LOCALAPPDATA%\recetarios-mama\` |
| Linux | `~/.local/share/recetarios-mama/` |
| Android | (new installation) |
| iOS | (new installation) |

The Dart implementation must resolve the **same path** on Windows and Linux so it
finds the existing `recetarios.db` and `images/` directory without any migration step.
Path resolution in `app_database.dart`:

```dart
// Windows
Platform.environment['LOCALAPPDATA']! + r'\recetarios-mama'

// Linux
(Platform.environment['XDG_DATA_HOME']
    ?? '${Platform.environment['HOME']}/.local/share')
    + '/recetarios-mama'

// Android / iOS
(await getApplicationDocumentsDirectory()).path
```

---

## New files: `frontend/lib/data/local/`

### `app_database.dart`
- Opens SQLite at the resolved data dir path
- On mobile: uses `sqflite` directly
- On desktop: calls `sqfliteFfiInit()` + `databaseFactoryFfi` before opening
- Checks `PRAGMA user_version`; if it equals 2 → existing database, open as-is
- If no database exists → create fresh schema (same DDL as Python `db.py`)
- Exposes a single `Database` instance consumed by all other local services

### `repository.dart`
Direct SQL CRUD mirroring Python `storage/repository.py`:
- `listBooks / getBook / createBook / updateBook / deleteBook / reorderBooks`
- `listChapters / getChapter / createChapter / updateChapter / deleteChapter / reorderChapters`
  - Includes `chapterHasSubchapters` and `chapterRecipeCount` helpers
- `listRecipes / getRecipe / createRecipe / updateRecipe / deleteRecipe / reorderRecipes`
- `search(query)` — FTS5 MATCH with BM25 ranking + `snippet()` function + breadcrumb assembly
- `rebuildFts()` — full index rebuild (used after archive import)
- FTS maintenance: `_ftsUpsert / _ftsDelete / _ftsPurgeOrphans` on every write

Markdown plain-text extraction for FTS indexing: strip `![...]()` image refs and
common Markdown punctuation so only searchable words are indexed (mirrors Python
`models/markdown.py plain_text()`).

### `image_store.dart`
Content-addressed store mirroring Python `storage/images.py`:
- `ingest(Uint8List bytes)` → SHA-256 hash, detect JPEG/PNG/GIF/WebP/BMP, store at
  `<data-dir>/images/<hash>.<ext>`, record in `images` table, return `{hash, ext, width, height}`
- `pathFor(String hash)` → absolute file path or null
- `exists(String hash)` → bool
- Image dimensions via `dart:ui` `decodeImageFromList` (or `image` package)

### `settings_store.dart`
Key-value settings in the `settings` table (mirrors Python `services/settings.py`):
- `getAll()` → `Map<String, String>` with `pdf_output_dir` defaulting to home dir
- `get(key)` → single value
- `update(Map<String, String> values)` — upsert

### `archive_service.dart`
`.recetarios` ZIP export/import (mirrors Python `services/archive.py`, format v2):
- `export(String targetPath)` → writes ZIP with `library.json` + `images/<hash>.<ext>`
- `importReplace(String sourcePath)` → validates manifest, ingests images, replaces library in one transaction, rebuilds FTS
- Must reject archives with `format_version != 2` (error code `archive_unsupported_version`)
- ZIP handling via the `archive` package

### `pdf_service.dart`
PDF generation using the `pdf` Dart package (mirrors Python `services/pdf/`):
- `buildRecipePdf(recipeId, {includeIntroduction, includeImages, outputDir})` → saves file, returns path
- `buildBookPdf(bookId, {outputDir})` → saves file, returns path
- Layout: cover page, table of contents, chapter section headers, recipe pages
- Markdown → PDF: parse with `markdown` package AST → emit `pw.Widget` nodes
  (paragraphs, bold/italic, bullet lists, tables, inline images)
- Images: embedded as JPEG/PNG bytes from the image store
- Font: Helvetica equivalent (built-in `pdf` package fonts cover Latin-1 / Spanish)
- Page size: A4

> PDF output will look different from the current ReportLab version. This is accepted.

---

## Modified files

### `pubspec.yaml`
- Add packages above; remove `dio`; bump version `1.2.1+1 → 1.3.0+1`

### `lib/main.dart`
Replace `BackendConnection.establish()` + `ApiClient` bootstrap with:
```dart
final db = await AppDatabase.open();
// No lifecycle teardown needed — sqflite closes cleanly on process exit
runApp(ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: RecetariosApp(),
));
```
Remove `_BackendLifecycle` and `_BootFailure` (no external process to fail).

### `lib/app/providers.dart`
Replace `apiClientProvider` with:
```dart
final appDatabaseProvider = Provider<AppDatabase>(...);
final repositoryProvider  = Provider<LocalRepository>(...);
final imageStoreProvider  = Provider<ImageStore>(...);
final settingsProvider    = Provider<SettingsStore>(...);
```

### `lib/data/books_repository.dart`
Replace `ApiClient` calls with `LocalRepository` method calls. Method signatures unchanged.

### `lib/data/chapters_repository.dart`
Same pattern.

### `lib/data/recipes_repository.dart`
Same pattern.

### `lib/features/transfer/library_transfer_flow.dart`
- Export: call `ArchiveService.export(path)` directly instead of `POST /library/export`
- Import: call `ArchiveService.importReplace(path)` directly instead of `POST /library/import`

### `lib/features/books/export_book_pdf.dart`
Call `PdfService.buildBookPdf(bookId)` directly; open result with `printing` package or `open_filex`.

### `lib/features/recipes/print_dialog.dart`
Call `PdfService.buildRecipePdf(recipeId, ...)` directly.

### `lib/features/settings/settings_screen.dart`
Read/write via `SettingsStore` instead of `GET /settings` / `PUT /settings`.

---

## Deleted files

| File | Why |
|---|---|
| `frontend/lib/core/backend.dart` | Python process management — no longer exists |
| `frontend/lib/data/api_client.dart` | HTTP client — no longer used |
| `backend/` (entire directory) | Python backend — replaced |

---

## Android setup (done as part of this migration)

1. Launcher icons: generate mipmap PNGs from `icon/icon_*.png`:
   - mdpi=48px, hdpi=72px, xhdpi=96px, xxhdpi=144px, xxxhdpi=192px
   - Place at `frontend/android/app/src/main/res/mipmap-*/ic_launcher.png`
2. Release signing:
   - Generate keystore, store credentials in GitHub Secrets
   - Configure `build.gradle.kts` with signing config
3. Update `AndroidManifest.xml`: app label, internet permission (remove if HTTP gone)

---

## Build script changes

### `build/build-windows.ps1`
- Remove PyInstaller invocation and `backend/` copy step
- Remove `venv` setup
- Flutter build + dist copy only — significantly simpler

### `build/installer.iss`
- Remove `[Files]` section entries for `backend\*`
- Remove backend directory creation

### `.github/workflows/release.yml`
- Remove Python setup, `pip install`, pytest, and PyInstaller steps
- Add Android APK build job:
  ```yaml
  - uses: actions/setup-java@v4
  - run: flutter build apk --release
  - upload APK as release asset
  ```

---

## Legacy import

The legacy importer (`POST /import/legacy`) handles an old XML-based format. It is
**deferred**: stub the UI flow to show "no disponible en esta versión" for now. Can be
re-implemented in Dart later if still needed.

---

## Implementation sequence

1. `pubspec.yaml` — add packages
2. `app_database.dart` — open existing `recetarios.db`, verify schema v2 reads correctly on Windows
3. `repository.dart` — CRUD + FTS search, test against live data
4. `image_store.dart` — content-addressed store
5. `providers.dart` + `main.dart` — replace bootstrap
6. Repositories (`books`, `chapters`, `recipes`) — swap to local calls
7. `settings_store.dart` + settings screen
8. `archive_service.dart` + transfer UI
9. `pdf_service.dart` + PDF UI (most time-consuming step)
10. Android target: launcher icons + signing config
11. Build scripts: remove Python steps, add Android APK job
12. Delete `backend/` directory
13. Integration test: open existing Windows database, verify all data intact
14. Commit, push, CI, tag `v1.3.0`
