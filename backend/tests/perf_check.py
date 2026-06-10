"""Performance validation against spec success criteria (T077).

Run:  .venv\\Scripts\\python.exe tests\\perf_check.py
Imports the three real legacy books into a throwaway library, then times
search (SC-011 < 1 s) and whole-book PDF generation (SC-005 < 2 min) and
single-recipe PDF (SC-006 backend share of < 15 s).
"""

import sys
import tempfile
import time
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from recetarios.api.app import create_app  # noqa: E402

LEGACY = Path(__file__).resolve().parents[2] / "legacy"


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        data_dir = Path(tmp) / "data"
        out_dir = Path(tmp) / "pdf"
        out_dir.mkdir()
        with TestClient(create_app(data_dir)) as client:
            total_recipes = 0
            t0 = time.perf_counter()
            book_ids = []
            for doc in sorted(LEGACY.glob("*.json")):
                result = client.post(
                    "/import/legacy", json={"path": str(doc), "on_collision": "keep_both"}
                ).json()
                total_recipes += result["report"]["recipes"]
                book_ids.append(result["book_id"])
            import_s = time.perf_counter() - t0
            print(f"import: {total_recipes} recipes in {import_s:.1f}s")

            t0 = time.perf_counter()
            results = client.get("/search", params={"q": "champinon"}).json()
            search_s = time.perf_counter() - t0
            print(f"search 'champinon': {len(results)} hits in {search_s*1000:.0f}ms"
                  f"  (SC-011 target < 1000ms over {total_recipes} recipes)")

            biggest = max(
                book_ids,
                key=lambda b: sum(
                    c["recipe_count"] for c in client.get(f"/books/{b}/chapters").json()
                ),
            )
            t0 = time.perf_counter()
            job = client.post(f"/pdf/book/{biggest}", json={"output_dir": str(out_dir)}).json()
            while True:
                status = client.get(f"/pdf/jobs/{job['job_id']}").json()
                if status["status"] != "running":
                    break
                time.sleep(0.2)
            book_pdf_s = time.perf_counter() - t0
            assert status["status"] == "done", status
            size_kb = Path(status["path"]).stat().st_size // 1024
            print(f"book pdf: {book_pdf_s:.1f}s, {size_kb} KB  (SC-005 target < 120s)")

            recipe_id = client.get(
                f"/chapters/{client.get(f'/books/{biggest}/chapters').json()[0]['id']}/recipes"
            ).json()[0]["id"]
            t0 = time.perf_counter()
            client.post(
                f"/pdf/recipe/{recipe_id}",
                json={"include_introduction": True, "include_images": True,
                      "output_dir": str(out_dir)},
            )
            recipe_pdf_s = time.perf_counter() - t0
            print(f"recipe pdf: {recipe_pdf_s*1000:.0f}ms  (SC-006 backend share of < 15s)")

            verdicts = {
                "SC-011 search < 1s": search_s < 1.0,
                "SC-005 book pdf < 120s": book_pdf_s < 120.0,
                "SC-006 recipe pdf well under 15s": recipe_pdf_s < 5.0,
            }
            print()
            for name, ok in verdicts.items():
                print(f"{'PASS' if ok else 'FAIL'}  {name}")
            if not all(verdicts.values()):
                sys.exit(1)


if __name__ == "__main__":
    main()
