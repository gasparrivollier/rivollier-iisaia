import pytest
from botocore.stub import Stubber

from app.services.storage import Storage, StorageError


def _storage() -> Storage:
    return Storage(
        endpoint_url="http://minio:9000",
        public_url="http://127.0.0.1:9000",
        access_key="ak",
        secret_key="sk",
        bucket="photos",
    )


def test_presign_uses_public_endpoint():
    url = _storage().presign("identifications/1/a.png", expires=120)
    assert url.startswith("http://127.0.0.1:9000/photos/identifications/1/a.png?")
    assert "X-Amz-Signature=" in url and "X-Amz-Expires=120" in url
    assert "minio:9000" not in url


def test_put_creates_the_bucket_once_then_uploads():
    s = _storage()
    with Stubber(s._client) as stub:
        stub.add_client_error("head_bucket", service_error_code="404", http_status_code=404)
        stub.add_response("create_bucket", {}, {"Bucket": "photos"})
        for _ in range(2):
            stub.add_response(
                "put_object",
                {},
                {"Bucket": "photos", "Key": "k", "Body": b"x", "ContentType": "image/png"},
            )
        s.put("k", b"x", "image/png")
        s.put("k", b"x", "image/png")  # second call must not head/create again
        stub.assert_no_pending_responses()


def test_put_skips_create_when_the_bucket_exists():
    s = _storage()
    with Stubber(s._client) as stub:
        stub.add_response("head_bucket", {}, {"Bucket": "photos"})
        stub.add_response(
            "put_object",
            {},
            {"Bucket": "photos", "Key": "k", "Body": b"x", "ContentType": "image/png"},
        )
        s.put("k", b"x", "image/png")
        stub.assert_no_pending_responses()


def test_upload_failure_is_a_storage_error():
    s = _storage()
    with Stubber(s._client) as stub:
        stub.add_response("head_bucket", {}, {"Bucket": "photos"})
        stub.add_client_error(
            "put_object", service_error_code="InternalError", http_status_code=500
        )
        with pytest.raises(StorageError):
            s.put("k", b"x", "image/png")


def test_unreachable_storage_is_a_storage_error():
    s = Storage(
        endpoint_url="http://127.0.0.1:1",  # nothing listens here
        public_url="http://127.0.0.1:9000",
        access_key="ak",
        secret_key="sk",
        bucket="photos",
    )
    with pytest.raises(StorageError):
        s.put("k", b"x", "image/png")
