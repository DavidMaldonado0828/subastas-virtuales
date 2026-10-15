"""Almacenamiento intercambiable para imágenes de productos."""
from __future__ import annotations

from pathlib import Path, PurePosixPath
from typing import Protocol
from urllib.parse import urlsplit, urlunsplit
from uuid import uuid4

from fastapi import UploadFile

from app.core.config import BACKEND_DIR

MAX_IMAGE_BYTES = 2 * 1024 * 1024


class InvalidImage(ValueError):
    """El contenido no es uno de los formatos de imagen permitidos."""


class ImageTooLarge(ValueError):
    """La imagen supera el tamaño máximo permitido."""


class Storage(Protocol):
    async def save(self, file: UploadFile) -> str: ...
    def delete(self, url: str | None) -> None: ...


class DiskStorage:
    def __init__(self, root: Path | None = None) -> None:
        self.root = (root or BACKEND_DIR / "uploads" / "products").resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    async def save(self, file: UploadFile) -> str:
        content = await file.read(MAX_IMAGE_BYTES + 1)
        if len(content) > MAX_IMAGE_BYTES:
            raise ImageTooLarge("La imagen supera el límite de 2 MB.")
        extension = self._extension(content)
        if extension is None:
            raise InvalidImage("Formato no permitido. Sube una imagen JPEG, PNG o WEBP válida.")
        filename = f"{uuid4().hex}.{extension}"
        (self.root / filename).write_bytes(content)
        return f"/media/products/{filename}"

    def delete(self, url: str | None) -> None:
        if not url:
            return
        parsed = urlsplit(url)
        parts = PurePosixPath(parsed.path).parts
        if parsed.scheme or parsed.netloc or len(parts) != 4 or parts[1:3] != ("media", "products"):
            return
        candidate = (self.root / parts[3]).resolve()
        if candidate.parent == self.root:
            candidate.unlink(missing_ok=True)

    @staticmethod
    def _extension(content: bytes) -> str | None:
        if content.startswith(b"\xff\xd8\xff"):
            return "jpg"
        if content.startswith(b"\x89PNG\r\n\x1a\n"):
            return "png"
        if len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP":
            return "webp"
        return None


storage: Storage = DiskStorage()


def public_url(url: str | None, base_url: str | None) -> str | None:
    if not url or not base_url:
        return url
    parsed = urlsplit(url)
    if parsed.scheme in {"http", "https"}:
        return url
    base = urlsplit(base_url)
    return urlunsplit((base.scheme, base.netloc, parsed.path, parsed.query, parsed.fragment))
