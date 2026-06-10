"""US7: settings persistence and validation (FR-033/035)."""

from pathlib import Path

from fastapi.testclient import TestClient

from recetarios.api.app import create_app


def test_default_pdf_output_dir_is_user_folder(client):
    settings = client.get("/settings").json()
    assert settings["pdf_output_dir"] == str(Path.home())


def test_update_and_persist_across_restart(client, data_dir, tmp_path):
    target = tmp_path / "salida"
    target.mkdir()
    response = client.put("/settings", json={"pdf_output_dir": str(target)})
    assert response.status_code == 200
    assert response.json()["pdf_output_dir"] == str(target)

    # Fresh app over the same data dir simulates an application restart.
    with TestClient(create_app(data_dir)) as restarted:
        assert restarted.get("/settings").json()["pdf_output_dir"] == str(target)


def test_rejects_missing_directory(client):
    response = client.put("/settings", json={"pdf_output_dir": "Z:\\no\\existe"})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "output_dir_invalid"
