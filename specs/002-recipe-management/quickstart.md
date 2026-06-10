# Quickstart: Recipe Management Development

**Feature**: `002-recipe-management` | **Date**: 2026-06-10

## Prerequisites

- **Flutter SDK** 3.x stable (`flutter doctor` clean for Windows desktop: Visual Studio C++ workload installed)
- **Python** 3.12 on PATH
- Windows 10/11 (primary target); the repo's `legacy/` directory present (real import data + schema)

## Backend (Python / FastAPI)

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -e .[dev]          # fastapi, uvicorn, pydantic, reportlab, pillow + pytest, ruff, httpx

# Run in dev mode (fixed port for convenience)
python -m recetarios --port 8765 --data-dir ..\.devdata

# Tests & lint
pytest
ruff check src tests
```

- API docs while running: `http://127.0.0.1:8765/docs`
- Golden import tests parse the real books under `legacy/` — keep that directory intact.

## Frontend (Flutter)

```powershell
cd frontend
flutter pub get
flutter gen-l10n

# Point the app at the dev backend instead of spawning the bundled one
$env:RECETARIOS_BACKEND_URL = "http://127.0.0.1:8765"
flutter run -d windows

# Tests
flutter test
flutter test integration_test -d windows
```

Without `RECETARIOS_BACKEND_URL`, the app launches the backend itself: in dev it uses `RECETARIOS_BACKEND_CMD` (e.g., `python -m recetarios`) and in packaged builds the bundled PyInstaller executable at its known relative path.

## Try the core loop (manual smoke)

1. Start backend + frontend as above.
2. Import a legacy book: Menu → "Importar recetario antiguo" → select `legacy/recetas_de_mama.json` → check the import report (chapters/recipes/images counts).
3. Browse: book → chapters (note nested subchapters) → recipes → open one; toggle titles-only mode; try search ("champinon" should match "champiñón").
4. Edit a recipe, save, then print it to PDF skipping images; the PDF should open automatically.
5. Export the book PDF and verify cover, indented index, chapter intro pages, one recipe per page.
6. Settings → change PDF output folder → restart app → verify it persisted.

## Packaged Windows build

```powershell
# From repo root — assembles dist/recetarios-mama/
.\build\build-windows.ps1   # 1) pyinstaller backend  2) flutter build windows  3) copy backend into the app folder
```

Other targets later via the same script family: `flutter build apk` (Android, backend via serious_python — see research R2) and `flutter build linux` + Linux PyInstaller.

## Project layout reference

See `plan.md` → Project Structure. Contracts in `contracts/rest-api.md`; entity shapes in `data-model.md`.

## Validated (2026-06-10, /speckit-implement run)

- ✅ Backend: 80 pytest tests green (unit + API integration + golden imports of the three real `legacy/` books with 100% chapter/recipe preservation); `ruff check` clean.
- ✅ Frontend: `flutter analyze` clean; 13 widget tests green (responsive grid, ellipsis truncation, display-mode toggle, view-section order, save/discard semantics, editors).
- ✅ Performance: see `perf-notes.md` — SC-005/006/011 pass with wide margins on the real library (561 recipes).
- ✅ Packaged backend: PyInstaller one-folder build starts, prints the `RECETARIOS_PORT` handshake with `console=False`, serves `/health`, and shuts down gracefully.
- ✅ Windows packaging (after installing VS 2022 Build Tools 17.14 + C++ workload): `.\build\build-windows.ps1` produces `dist\recetarios-mama\` (Flutter release build 132 s + PyInstaller backend bundled at `backend\recetarios.exe`).
- ✅ Packaged-app smoke: launching `dist\recetarios-mama\recetarios.exe` spawns the bundled backend (2 processes), shows the app window, and closing the window terminates both processes cleanly (graceful shutdown + parent watchdog verified).
- ✅ Desktop e2e (`flutter test integration_test -d windows` against a dev backend): boots the real app, renders the Spanish book list, creates a book, and navigates into the empty-chapter state — all passing.
