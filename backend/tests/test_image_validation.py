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


def test_rejects_a_huge_pixel_count_before_decoding_it():
    # ~64 MP compresses to a few hundred KB, so the byte cap alone would let it through.
    with pytest.raises(ImageRejected) as exc:
        validate_image(png_bytes(8000, 8000))
    assert exc.value.status_code == 422
    assert "megapixel" in exc.value.message


from app.services.image_validation import (  # noqa: E402
    MAX_IMAGES,
    MAX_TOTAL_BYTES,
    ORGANS,
    validate_image_set,
    validate_set_shape,
)


def test_organs_are_the_pl_ntnet_set():
    assert ORGANS == ("auto", "leaf", "flower", "fruit", "bark")


def test_set_shape_accepts_one_to_five_matching_organs():
    validate_set_shape(1, ["auto"])
    validate_set_shape(MAX_IMAGES, ["leaf"] * MAX_IMAGES)


@pytest.mark.parametrize(
    ("n", "organs", "fragment"),
    [
        (0, [], "at least one"),
        (MAX_IMAGES + 1, ["auto"] * (MAX_IMAGES + 1), "At most"),
        (2, ["auto"], "organ"),
        (1, ["auto", "leaf"], "organ"),
        (2, ["auto", "petal"], "Photo 2"),
        (1, [""], "Photo 1"),
        (1, ["Leaf"], "Photo 1"),  # case-sensitive, like Pl@ntNet
    ],
)
def test_set_shape_rejects_bad_counts_and_unknown_organs(n, organs, fragment):
    with pytest.raises(ImageRejected) as exc:
        validate_set_shape(n, organs)
    assert exc.value.status_code == 422
    assert fragment in exc.value.message


def test_image_set_returns_validated_images_in_order():
    out = validate_image_set(
        [png_bytes(), jpeg_bytes(900, 900), png_bytes(1000, 800)], ["flower", "leaf", "auto"]
    )
    assert [v.ext for v in out] == ["png", "jpg", "png"]
    assert [(v.width, v.height) for v in out] == [(800, 800), (900, 900), (1000, 800)]


@pytest.mark.parametrize(
    ("bad", "fragment"),
    [
        (b"GIF89a" + b"\x00" * 100, "JPEG"),
        (png_bytes(100, 100), "800"),
        (b"\x89PNG\r\n\x1a\n" + b"junk" * 50, "could not be read"),
    ],
    ids=["gif", "undersized", "corrupt"],
)
def test_image_set_names_the_offending_photo(bad, fragment):
    with pytest.raises(ImageRejected) as exc:
        validate_image_set([png_bytes(), bad, png_bytes()], ["auto"] * 3)
    assert exc.value.status_code == 422
    assert exc.value.message.startswith("Photo 2: ")
    assert fragment in exc.value.message


def test_image_set_keeps_the_413_status_of_an_oversize_photo():
    big = b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024)
    with pytest.raises(ImageRejected) as exc:
        validate_image_set([png_bytes(), big], ["auto", "auto"])
    assert exc.value.status_code == 413
    assert exc.value.message.startswith("Photo 2: ")


def test_image_set_rejects_a_total_over_pl_ntnets_50mb_cap_before_decoding():
    # Each photo is under the 10 MiB cap, but five of them exceed 50 MB. Garbage bytes prove
    # the check runs before any decoding.
    each = MAX_TOTAL_BYTES // 5 + 1
    files = [b"\x89PNG\r\n\x1a\n" + b"0" * each for _ in range(5)]
    with pytest.raises(ImageRejected) as exc:
        validate_image_set(files, ["auto"] * 5)
    assert exc.value.status_code == 413
    assert "50 MB" in exc.value.message
