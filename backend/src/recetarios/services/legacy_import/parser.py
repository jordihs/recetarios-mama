"""Normalization helpers for the legacy JSON format.

The legacy schema (legacy/schema/recetarios-schema.json) declares many
single-or-array `oneOf` shapes; everything funnels through `as_list`.
Documents converted from XML carry formatting whitespace, collapsed by
`clean_text`. Unknown keys (stray HTML leftovers) are simply ignored.
"""

import json
import re
from pathlib import Path

from recetarios.api.errors import ApiError

_WHITESPACE = re.compile(r"\s+")


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


def load_document(path: Path) -> dict:
    """Read and minimally validate a legacy document; returns the RECETARIO node."""
    if not path.is_file():
        raise ApiError("legacy_file_not_found")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ApiError("legacy_invalid_format") from exc
    recetario = data.get("RECETARIO") if isinstance(data, dict) else None
    if not isinstance(recetario, dict) or not recetario.get("TITULO"):
        raise ApiError("legacy_invalid_format")
    return recetario
