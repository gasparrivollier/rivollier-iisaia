"""Server-side photo checks, run before any Pl@ntNet call (a rejected call still costs a credit).

Mirrors the client's `photoProblem()` in client/lib/data/photo_validation.dart.
"""

import io
from dataclasses import dataclass

from PIL import Image, UnidentifiedImageError

MAX_IMAGE_BYTES = 10 * 1024 * 1024
MIN_SIDE_PX = 800
# A tiny, highly compressible PNG can still decode to hundreds of MB of pixels.
MAX_PIXELS = 50_000_000
MAX_IMAGES = 5
# Pl@ntNet rejects requests over 50 MB; five photos at the 10 MiB per-photo cap would exceed it.
MAX_TOTAL_BYTES = 50_000_000
ORGANS = ("auto", "leaf", "flower", "fruit", "bark")

_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
_JPEG_MAGIC = b"\xff\xd8\xff"


class ImageRejected(Exception):
    def __init__(self, message: str, status_code: int = 422):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


@dataclass(frozen=True)
class ValidatedImage:
    ext: str
    content_type: str
    width: int
    height: int


def validate_image(data: bytes) -> ValidatedImage:
    if len(data) > MAX_IMAGE_BYTES:
        raise ImageRejected("Photo is larger than 10 MB", status_code=413)
    if data.startswith(_PNG_MAGIC):
        ext, content_type = "png", "image/png"
    elif data.startswith(_JPEG_MAGIC):
        ext, content_type = "jpg", "image/jpeg"
    else:
        raise ImageRejected("Only JPEG and PNG photos are supported")
    try:
        with Image.open(io.BytesIO(data)) as img:
            width, height = img.size
            if width * height > MAX_PIXELS:
                raise ImageRejected(
                    f"Photo is too large ({width}x{height}); the limit is "
                    f"{MAX_PIXELS // 1_000_000} megapixels"
                )
            img.load()  # full decode: catches truncated files that still have a valid header
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, Image.DecompressionBombError):
        raise ImageRejected("That file could not be read as an image") from None
    if width < MIN_SIDE_PX or height < MIN_SIDE_PX:
        raise ImageRejected(
            f"Photo must be at least {MIN_SIDE_PX}x{MIN_SIDE_PX} pixels "
            f"(this one is {width}x{height})"
        )
    return ValidatedImage(ext=ext, content_type=content_type, width=width, height=height)


def validate_set_shape(n_images: int, organs: list[str]) -> None:
    """Cheap checks on counts and organ tags; run before reading any file body."""
    if n_images < 1:
        raise ImageRejected("Add at least one photo")
    if n_images > MAX_IMAGES:
        raise ImageRejected(f"At most {MAX_IMAGES} photos per identification")
    if len(organs) != n_images:
        raise ImageRejected(
            f"Got {n_images} photo(s) but {len(organs)} organ tag(s); send one organ per photo"
        )
    for i, organ in enumerate(organs, start=1):
        if organ not in ORGANS:
            raise ImageRejected(
                f"Photo {i}: unknown organ {organ[:20]!r} (use one of: {', '.join(ORGANS)})"
            )


def validate_image_set(files: list[bytes], organs: list[str]) -> list[ValidatedImage]:
    validate_set_shape(len(files), organs)
    if sum(len(f) for f in files) > MAX_TOTAL_BYTES:
        raise ImageRejected("Photos total more than 50 MB", status_code=413)
    validated = []
    for i, data in enumerate(files, start=1):
        try:
            validated.append(validate_image(data))
        except ImageRejected as e:
            raise ImageRejected(f"Photo {i}: {e.message}", status_code=e.status_code) from None
    return validated
