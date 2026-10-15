"""S3-protocol adapter over MinIO. The bucket is created lazily on first upload (idempotent)."""

from functools import lru_cache

import boto3
from botocore.client import Config
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import Depends

from app.config import Settings, get_settings


class StorageError(Exception):
    pass


class Storage:
    def __init__(
        self, *, endpoint_url: str, public_url: str, access_key: str, secret_key: str, bucket: str
    ):
        common = {
            "aws_access_key_id": access_key,
            "aws_secret_access_key": secret_key,
            "region_name": "us-east-1",
            "config": Config(
                signature_version="s3v4",
                s3={"addressing_style": "path"},
                connect_timeout=5,
                read_timeout=15,
                retries={"max_attempts": 2},
            ),
        }
        self._client = boto3.client("s3", endpoint_url=endpoint_url, **common)
        # Presigning is a local computation, so a second client bound to the public host is free.
        self._signer = boto3.client("s3", endpoint_url=public_url, **common)
        self._bucket = bucket
        self._bucket_ready = False

    def _ensure_bucket(self) -> None:
        if self._bucket_ready:
            return
        try:
            self._client.head_bucket(Bucket=self._bucket)
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") not in ("404", "NoSuchBucket", "NotFound"):
                raise
            self._client.create_bucket(Bucket=self._bucket)
        self._bucket_ready = True

    def put(self, key: str, data: bytes, content_type: str) -> None:
        try:
            self._ensure_bucket()
            self._client.put_object(
                Bucket=self._bucket, Key=key, Body=data, ContentType=content_type
            )
        except (BotoCoreError, ClientError):
            raise StorageError("Could not store the photo") from None

    def presign(self, key: str, expires: int = 3600) -> str:
        return self._signer.generate_presigned_url(
            "get_object", Params={"Bucket": self._bucket, "Key": key}, ExpiresIn=expires
        )


@lru_cache
def _storage_for(
    endpoint_url: str, public_url: str, access_key: str, secret_key: str, bucket: str
) -> Storage:
    return Storage(
        endpoint_url=endpoint_url,
        public_url=public_url,
        access_key=access_key,
        secret_key=secret_key,
        bucket=bucket,
    )


def get_storage(settings: Settings = Depends(get_settings)) -> Storage:
    return _storage_for(
        settings.s3_endpoint_url,
        settings.s3_public_url,
        settings.s3_access_key,
        settings.s3_secret_key,
        settings.s3_bucket,
    )
