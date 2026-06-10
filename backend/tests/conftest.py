"""Shared pytest fixtures: isolated data dir + API test client per test."""

from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from recetarios.api.app import create_app
from recetarios.storage.db import Database


@pytest.fixture()
def data_dir(tmp_path: Path) -> Path:
    d = tmp_path / "data"
    d.mkdir()
    return d


@pytest.fixture()
def db(data_dir: Path) -> Iterator[Database]:
    database = Database(data_dir)
    yield database
    database.close()


@pytest.fixture()
def client(data_dir: Path) -> Iterator[TestClient]:
    app = create_app(data_dir)
    with TestClient(app) as c:
        yield c


LEGACY_DIR = Path(__file__).resolve().parents[2] / "legacy"
