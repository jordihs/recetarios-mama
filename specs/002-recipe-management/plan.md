# Implementation Plan: Recipe Management

**Branch**: `002-recipe-management` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-recipe-management/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

A local, offline recipe-management application: books → (nested) chapters → recipes, with rich presentation content (paragraphs, images, tables, grids), legacy JSON import, full-library backup/restore, full-text search, and print-quality PDF output (whole book with cover/index, or single recipe with include/skip options). The UI is built with **Flutter** (Spanish, responsive from phone to desktop); all domain logic, persistence, legacy import, search, and PDF generation live in a **Python backend** exposed as a private localhost REST API. Primary deliverable is a **Windows desktop app** where the Flutter shell spawns and supervises the bundled Python backend; the API-first split keeps Android APK and Linux builds achievable later without rearchitecting.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x (stable channel) for the GUI; Python 3.12 for the backend service

**Primary Dependencies**: Flutter: `riverpod` (state), `go_router` (navigation), `dio` (HTTP client), `flutter_quill` (rich text editing with custom image/grid embeds), `file_selector` (folder picking), `open_filex` (open generated PDFs), `flutter_localizations` + `gen-l10n` (Spanish UI). Python: `fastapi` + `uvicorn` (REST API), `pydantic` v2 (schemas/validation), `sqlite3` stdlib + FTS5 (storage & search), `reportlab` (PDF generation), `pillow` (image processing), `pyinstaller` (backend packaging)

**Storage**: SQLite database (WAL mode, UTF-8) + content-addressed image files under the per-user application data directory; SQLite FTS5 (`unicode61 remove_diacritics 2`) for accent-insensitive full-text search

**Testing**: Backend: `pytest` (unit + API integration via `httpx` TestClient, golden tests for legacy import against the real files in `legacy/`). Frontend: `flutter test` (unit + widget), `integration_test` for the critical browse/edit/print journeys

**Target Platform**: Windows 10/11 desktop (primary, packaged as Flutter Windows app + PyInstaller backend). Android APK and Linux desktop kept open via the same Flutter codebase and API contract (see research R2 for the mobile backend strategy)

**Project Type**: Desktop/mobile application — Flutter frontend + local Python backend (two top-level projects)

**Performance Goals**: Search < 1 s over 1,000 recipes (SC-011); book PDF (100 recipes with images) < 2 min (SC-005); single recipe PDF end-to-end < 15 s (SC-006); recipe lists with 200+ entries scroll smoothly and display-mode toggle feels instantaneous (SC-009)

**Constraints**: Fully offline (no network services; API bound to 127.0.0.1 only); all text stored UTF-8; UI language Spanish, code/docs English (constitution VI); no login; single local user; original `legacy/` directory is read-only input

**Scale/Scope**: Personal library scale — single user, ~3–10 books, up to ~1,000 recipes, a few GB of images; ~10 screens (book list, chapter list, recipe list, recipe view/edit, create forms, search, settings, import/export dialogs)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Assessment | Status |
|---|-----------|------------|--------|
| I | Code Quality First | Idiomatic Dart (Flutter lints) and Python (ruff + type hints); clear layering (UI → API client → REST → services → repository); no speculative abstractions | PASS |
| II | Testing Excellence | pytest for all backend logic incl. golden legacy-import tests against real `legacy/` data; flutter unit/widget tests; integration tests for P1–P3 journeys; CI-runnable, fast, repeatable | PASS |
| III | UX Consistency | One shared list-card pattern for books/chapters/recipes; Material 3 design system; consistent Spanish wording via centralized l10n ARB files | PASS |
| IV | Performance & Efficiency | Targets quantified in Technical Context (from spec SCs); FTS5 index and paged lists chosen specifically to meet them | PASS |
| V | Simplicity (YAGNI) | Two projects only (frontend, backend); stdlib `sqlite3` instead of ORM; no plugin system, no sync, no auth | PASS |
| VI | Language Standards | All artifacts in English; UI strings only in Spanish ARB resources; UTF-8 enforced at DB and API layers | PASS |

**Post-Phase-1 re-check**: design artifacts (data-model.md, contracts/rest-api.md) introduce no additional projects or patterns beyond the above — still PASS.

## Project Structure

### Documentation (this feature)

```text
specs/002-recipe-management/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── rest-api.md      # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
backend/
├── src/
│   └── recetarios/
│       ├── __main__.py          # entry point: parse --port/--data-dir, start uvicorn on 127.0.0.1
│       ├── api/                 # FastAPI routers (books, chapters, recipes, search, import/export, pdf, settings)
│       ├── models/              # pydantic schemas + content-block model
│       ├── services/            # domain logic: library, legacy_import, archive, search, pdf
│       │   └── pdf/             # ReportLab document builders (book, recipe)
│       ├── storage/             # sqlite repository, schema/migrations, image store
│       └── l10n/                # Spanish user-facing message catalog (import reports, errors)
└── tests/
    ├── unit/
    ├── integration/             # API-level tests (httpx TestClient)
    └── golden/                  # legacy import fixtures + assertions against legacy/*.json

frontend/
├── lib/
│   ├── main.dart
│   ├── app/                     # MaterialApp, router, theme, l10n setup
│   ├── core/                    # backend process launcher/supervisor, config
│   ├── data/                    # API client (dio), DTOs, repositories
│   ├── features/
│   │   ├── books/               # book list + create/edit form
│   │   ├── chapters/            # chapter list (recursive for subchapters) + form
│   │   ├── recipes/             # recipe list (toggle), recipe view, recipe editor
│   │   ├── search/
│   │   ├── transfer/            # legacy import, library export/import dialogs
│   │   └── settings/
│   └── widgets/                 # shared item card, content-block renderer/editor
├── l10n/                        # app_es.arb (Spanish UI strings)
├── test/                        # unit + widget tests
├── integration_test/
└── windows/ android/ linux/     # Flutter platform shells (windows is the packaged target)
```

**Structure Decision**: Two top-level projects, `backend/` (Python FastAPI service, all domain logic) and `frontend/` (Flutter app, all UI). They meet only at the REST contract in `contracts/rest-api.md`, which is what keeps the Windows-first build replaceable by Android/Linux targets later.

## Complexity Tracking

No constitution violations to justify — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
