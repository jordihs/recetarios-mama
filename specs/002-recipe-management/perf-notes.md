# Performance Validation Notes (T077)

**Date**: 2026-06-10 | **Hardware**: Windows 11 Pro developer machine | **Method**: `backend/tests/perf_check.py` (repeatable; imports the three real legacy books into a throwaway library, then times the targeted operations through the API)

## Results

| Success criterion | Target | Measured | Verdict |
|---|---|---|---|
| SC-011 full-text search over the library | < 1 s (1,000 recipes) | **6 ms** over 561 real recipes | PASS |
| SC-005 whole-book PDF (100 recipes w/ images) | < 2 min | **5.1 s** for the largest real book (220 recipes, 3.3 MB PDF) | PASS |
| SC-006 single recipe PDF (backend share of 15 s end-to-end) | well under 15 s | **8 ms** | PASS |
| (context) legacy import of all 3 books, 561 recipes | — | 1.3 s | — |

## SC-009 (list scrolling & toggle < 100 ms)

The recipe list payload is summaries-only (`id`, `title`, `image`, `description`) and the titles-only toggle is a pure client-side re-render of already-loaded data (no network round trip), switching between `GridView`/`ListView.builder` lazy builders. Expected to be well inside the 100 ms budget; final on-device confirmation pends the Windows desktop build (blocked: Visual Studio not installed — see quickstart validation notes).

## Notes

- Search uses SQLite FTS5 (`unicode61 remove_diacritics 2`) with bm25 ranking; index updated synchronously on recipe writes and rebuilt after archive restore.
- Book PDF generation runs as a background job with polling, so the UI stays responsive regardless of book size.
