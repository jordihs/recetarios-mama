# recetarios-mama

A local, offline recipe-book manager: organize cooking recipes into books and
(nested) chapters, import a legacy JSON recipe collection, search everything,
and print — single recipes or whole books with cover and index — as PDF.
The UI is in Spanish; all code and documentation are in English.

## Architecture

Two projects meeting only at a localhost REST API:

- **`backend/`** — Python 3.12 service (FastAPI + SQLite/FTS5 + ReportLab).
  Owns all domain logic: persistence, legacy import, full-text search,
  library backup archives, and PDF generation. Binds to `127.0.0.1` on an
  ephemeral port and announces it on stdout (`RECETARIOS_PORT=<n>`).
- **`frontend/`** — Flutter app (Riverpod + go_router). Spawns and supervises
  the backend on desktop, renders the responsive Spanish UI from phone to
  desktop sizes.

Rich content (book/chapter introductions, recipe introduction and
preparation) is stored as **markdown** (CommonMark + GFM tables; images as
`image://<sha256>` URIs into the content-addressed store). One canonical
document feeds screen rendering, the WYSIWYG editor (appflowy_editor with an
unobtrusive raw-source view), full-text search, list descriptions, and PDF
output. Editing is a single document per section — no per-paragraph controls.
See `specs/002-recipe-management/` for the baseline architecture and
`specs/003-content-editing-ordering/` for the markdown content model, the
ordered v2 legacy import, and the schema-v2 reset flow.

## Development

See [`specs/002-recipe-management/quickstart.md`](specs/002-recipe-management/quickstart.md)
for setup, dev-mode run (`RECETARIOS_BACKEND_URL`), tests, and the manual
smoke checklist.

```powershell
# Backend
cd backend; .venv\Scripts\Activate.ps1
pytest                 # incl. golden ordering checks against the real legacy books
python -m recetarios --port 8765 --data-dir ..\.devdata

# Frontend
cd frontend
flutter analyze; flutter test
$env:RECETARIOS_BACKEND_URL = "http://127.0.0.1:8765"; flutter run -d windows
```

## Building the Windows app

```powershell
.\build\build-windows.ps1   # PyInstaller backend + flutter build windows → dist/recetarios-mama/
```

Requires the Flutter SDK and Visual Studio with the C++ desktop workload.
Android (`flutter build apk` + serious_python) and Linux builds are kept open
by the API-first architecture — see research note R2.

## Legacy data

The `legacy/` directory holds the original family recipe collection (JSON per
`legacy/schema/recetarios-schema.json` **v2** — ordered `CONTENIDO` arrays —
images under `legacy/imgs/`). It is read-only input: golden tests import all
three books end-to-end, assert 100% content preservation, and machine-check
that every introduction's element order equals the source order. v1-shaped
documents (grouped block keys) are rejected at import.

## Vendored dependency

`frontend/third_party/appflowy_editor/` is a one-line-patched copy of
appflowy_editor 6.2.0 (the published release does not compile against the
project's Flutter SDK). See `VENDORED.md` there for the patch and the
removal condition.
