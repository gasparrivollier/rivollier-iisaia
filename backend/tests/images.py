import io

from PIL import Image


def _encode(fmt: str, width: int, height: int) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), (40, 120, 60)).save(buf, fmt)
    return buf.getvalue()


def png_bytes(width: int = 800, height: int = 800) -> bytes:
    return _encode("PNG", width, height)


def jpeg_bytes(width: int = 800, height: int = 800) -> bytes:
    return _encode("JPEG", width, height)
