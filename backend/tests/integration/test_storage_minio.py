import uuid

import httpx
import pytest

from app.config import get_settings
from app.services.storage import Storage

pytestmark = pytest.mark.integration


def test_put_then_fetch_through_the_presigned_url():
    s = get_settings()
    storage = Storage(
        endpoint_url=s.s3_endpoint_url,
        public_url=s.s3_public_url,
        access_key=s.s3_access_key,
        secret_key=s.s3_secret_key,
        bucket=f"{s.s3_bucket}-test",  # separate bucket: also exercises lazy creation
    )
    key = f"it/{uuid.uuid4().hex}.png"
    storage.put(key, b"\x89PNG-bytes", "image/png")
    res = httpx.get(storage.presign(key, expires=60))
    assert res.status_code == 200
    assert res.content == b"\x89PNG-bytes"
    assert res.headers["content-type"] == "image/png"
