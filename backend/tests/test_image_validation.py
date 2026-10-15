import pytest

from app.services.image_validation import (
    MAX_IMAGE_BYTES,
    ImageRejected,
    validate_image,
)
from tests.images import jpeg_bytes, png_bytes


def test_accepts_png_at_the_minimum_size():
    v = validate_image(png_bytes(800, 800))
    assert (v.ext, v.content_type, v.width, v.height) == ("png", "image/png", 800, 800)


def test_accepts_jpeg_and_large_landscape():
    v = validate_image(jpeg_bytes(1600, 900))
    assert (v.ext, v.content_type) == ("jpg", "image/jpeg")


@pytest.mark.parametrize("size", [(799, 800), (800, 799), (100, 100)])
def test_rejects_images_smaller_than_800px_on_either_side(size):
    with pytest.raises(ImageRejected) as exc:
        validate_image(png_bytes(*size))
    assert exc.value.status_code == 422
    assert "800" in exc.value.message


def test_rejects_unsupported_formats_by_magic_bytes():
    with pytest.raises(ImageRejected) as exc:
        validate_image(b"GIF89a" + b"\x00" * 200)
    assert exc.value.status_code == 422
    assert "JPEG" in exc.value.message


def test_rejects_empty_input():
    with pytest.raises(ImageRejected):
        validate_image(b"")


def test_rejects_png_header_with_garbage_body():
    with pytest.raises(ImageRejected) as exc:
        validate_image(b"\x89PNG\r\n\x1a\n" + b"not really an image" * 20)
    assert exc.value.status_code == 422


def test_rejects_a_truncated_image():
    data = png_bytes(1200, 1200)
    with pytest.raises(ImageRejected):
        validate_image(data[: len(data) // 2])


def test_rejects_oversize_with_413_before_decoding():
    with pytest.raises(ImageRejected) as exc:
        validate_image(b"\x89PNG\r\n\x1a\n" + b"0" * MAX_IMAGE_BYTES)
    assert exc.value.status_code == 413
