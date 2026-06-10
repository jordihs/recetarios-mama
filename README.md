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

Content is stored as typed JSON blocks (paragraphs, headings, captioned
images, image grids, tables) that feed screen rendering, editing, and PDF
output from a single model. See `specs/002-recipe-management/` for the full
specification, plan, data model, and REST contract.

## Development

See [`specs/002-recipe-management/quickstart.md`](specs/002-recipe-management/quickstart.md)
for setup, dev-mode run (`RECETARIOS_BACKEND_URL`), tests, and the manual
smoke checklist.

```powershell
# Backend
cd backend; .venv\Scripts\Activate.ps1
pytest                 # 80 tests incl. golden imports of the real legacy books
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
`legacy/schema/recetarios-schema.json`, images under `legacy/imgs/`). It is
read-only input: golden tests import all three books end-to-end and assert
100% content preservation.
