"""Foundational: GET /library/status, POST /library/reset, legacy-format guard."""

import sqlite3
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from recetarios.api.app import create_app

# What feature 002's Database left on disk (user_version = 1).
_V1_SCHEMA = """
CREATE TABLE books (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    cover_image TEXT,
    presentation TEXT NOT NULL DEFAULT '[]',
    position    INTEGER NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
PRAGMA user_version = 1;
"""


@pytest.fixture()
def legacy_client(data_dir: Path):
    conn = sqlite3.connect(data_dir / "recetarios.db")
    conn.executescript(_V1_SCHEMA)
    conn.commit()
    conn.close()
    app = create_app(data_dir)
    with TestClient(app) as c:
        yield c


def test_status_current_on_fresh_library(client):
    response = client.get("/library/status")
    assert response.status_code == 200
    assert response.json() == {"format": "current"}


def test_status_legacy_on_v1_library(legacy_client):
    response = legacy_client.get("/library/status")
    assert response.status_code == 200
    assert response.json() == {"format": "legacy"}


def test_legacy_library_blocks_other_routes(legacy_client):
    response = legacy_client.get("/books")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "library_format_legacy"

    response = legacy_client.post("/books", json={"title": "Nuevo"})
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "library_format_legacy"


def test_health_and_status_exempt_from_guard(legacy_client):
    assert legacy_client.get("/health").status_code == 200
    assert legacy_client.get("/library/status").status_code == 200


def test_reset_requires_confirmation(legacy_client):
    response = legacy_client.post("/library/reset", json={})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "reset_confirm_required"

    response = legacy_client.post("/library/reset", json={"confirm": False})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "reset_confirm_required"


def test_reset_recreates_library_at_v2(legacy_client, data_dir):
    response = legacy_client.post("/library/reset", json={"confirm": True})
    assert response.status_code == 200
    assert response.json() == {"format": "current"}

    assert legacy_client.get("/library/status").json() == {"format": "current"}
    # The guard lifts and the library is empty and writable.
    assert legacy_client.get("/books").json() == []
    created = legacy_client.post("/books", json={"title": "Tras el reinicio"})
    assert created.status_code == 200


def test_reset_preserves_images_directory(legacy_client, data_dir):
    images_dir = data_dir / "images"
    images_dir.mkdir(exist_ok=True)
    keeper = images_dir / ("a" * 64 + ".png")
    keeper.write_bytes(b"png-bytes")

    response = legacy_client.post("/library/reset", json={"confirm": True})
    assert response.status_code == 200
    assert keeper.exists()


def test_reset_works_on_current_library_too(client):
    client.post("/books", json={"title": "Se borra"})
    response = client.post("/library/reset", json={"confirm": True})
    assert response.status_code == 200
    assert client.get("/books").json() == []


def test_spanish_messages_for_new_codes(legacy_client):
    blocked = legacy_client.get("/books").json()["error"]["message"]
    assert blocked  # non-empty Spanish text
    unconfirmed = legacy_client.post("/library/reset", json={}).json()["error"]["message"]
    assert "confirm" in unconfirmed.lower() or "confirmaci" in unconfirmed.lower()
