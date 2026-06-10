"""Content-addressed image store: files under <data-dir>/images/<sha256>.<ext>."""

import hashlib
import io
import shutil
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from recetarios.storage.db import Database

_EXT_BY_FORMAT = {"JPEG": "jpg", "PNG": "png", "GIF": "gif", "WEBP": "webp", "BMP": "bmp"}


class ImageStoreError(Exception):
    pass


class ImageStore:
    def __init__(self, db: Database):
        self.db = db
        self.dir = db.data_dir / "images"
        self.dir.mkdir(parents=True, exist_ok=True)

    def ingest(self, data: bytes) -> dict:
        """Store image bytes, return {hash, ext, width, height}. Dedupes by content."""
        try:
            probe = Image.open(io.BytesIO(data))
            fmt = probe.format or ""
            width, height = probe.size
        except UnidentifiedImageError as exc:
            raise ImageStoreError("unsupported or corrupt image data") from exc
        ext = _EXT_BY_FORMAT.get(fmt)
        if ext is None:
            raise ImageStoreError(f"unsupported image format: {fmt or 'unknown'}")
        digest = hashlib.sha256(data).hexdigest()
        path = self.dir / f"{digest}.{ext}"
        if not path.exists():
            path.write_bytes(data)
        self.db.conn.execute(
            "INSERT OR IGNORE INTO images(hash, ext, width, height) VALUES (?, ?, ?, ?)",
            (digest, ext, width, height),
        )
        self.db.conn.commit()
        return {"hash": digest, "ext": ext, "width": width, "height": height}

    def ingest_file(self, source: Path) -> dict:
        return self.ingest(Path(source).read_bytes())

    def path_for(self, hash_: str) -> Path | None:
        row = self.db.conn.execute("SELECT ext FROM images WHERE hash = ?", (hash_,)).fetchone()
        if row is None:
            return None
        path = self.dir / f"{hash_}.{row['ext']}"
        return path if path.exists() else None

    def exists(self, hash_: str) -> bool:
        return self.path_for(hash_) is not None

    def all_hashes(self) -> set[str]:
        rows = self.db.conn.execute("SELECT hash FROM images").fetchall()
        return {r["hash"] for r in rows}

    def copy_into(self, hash_: str, target_dir: Path) -> None:
        source = self.path_for(hash_)
        if source is not None:
            shutil.copy2(source, Path(target_dir) / source.name)
