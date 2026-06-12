"""Normalization and validation helpers for the legacy JSON format (schema v2).

The v2 schema (legacy/schema/recetarios-schema.json) represents every
introduction as an ordered ``CONTENIDO`` array. v1 documents — grouped
``PARRAFO``/``TITULO``/``IMAGEN``/``IMAGENES``/``TABLA`` keys directly on the
introduction object, or bare string introductions — are detected and rejected
(``legacy_v1_unsupported``); they lost the original element order, which is
the reason feature 003 exists.

Single-or-array ``oneOf`` shapes funnel through `as_list`. Documents
converted from XML carry formatting whitespace, collapsed by `clean_text`.
"""

import json
import re
from pathlib import Path

from recetarios.api.errors import ApiError

_WHITESPACE = re.compile(r"\s+")

_V1_INTRO_MARKERS = ("PARRAFO", "TITULO", "IMAGEN", "IMAGENES", "TABLA")


def as_list(value) -> list:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def clean_text(value) -> str:
    if value is None:
        return ""
    return _WHITESPACE.sub(" ", str(value)).strip()


def attr(node: dict, name: str) -> str | None:
    attributes = node.get("@attributes") or {}
    value = attributes.get(name)
    return clean_text(value) if value is not None else None


def _validate_introduccion(intro) -> None:
    if intro is None:
        return
    if isinstance(intro, str):
        raise ApiError("legacy_v1_unsupported")
    if not isinstance(intro, dict):
        raise ApiError("legacy_invalid_format")
    if any(marker in intro for marker in _V1_INTRO_MARKERS):
        raise ApiError("legacy_v1_unsupported")
    if "CONTENIDO" in intro and not isinstance(intro["CONTENIDO"], list):
        raise ApiError("legacy_invalid_format")


def _validate_chapters(chapters) -> None:
    for chapter in as_list(chapters):
        if not isinstance(chapter, dict):
            raise ApiError("legacy_invalid_format")
        _validate_introduccion(chapter.get("INTRODUCCION"))
        _validate_chapters(chapter.get("CAPITULO"))


def validate_v2(recetario: dict) -> None:
    """Walk every introduction; v1 shapes raise ``legacy_v1_unsupported``."""
    _validate_introduccion(recetario.get("INTRODUCCION"))
    _validate_chapters(recetario.get("CAPITULO"))


def load_document(path: Path) -> dict:
    """Read and validate a legacy document; returns the RECETARIO node."""
    if not path.is_file():
        raise ApiError("legacy_file_not_found")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ApiError("legacy_invalid_format") from exc
    recetario = data.get("RECETARIO") if isinstance(data, dict) else None
    if not isinstance(recetario, dict) or not recetario.get("TITULO"):
        raise ApiError("legacy_invalid_format")
    validate_v2(recetario)
    return recetario
