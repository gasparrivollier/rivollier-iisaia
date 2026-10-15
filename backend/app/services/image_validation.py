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
