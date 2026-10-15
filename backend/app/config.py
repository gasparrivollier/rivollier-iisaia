from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend settings. Read from env vars, then from the repo-root .env (git-ignored)."""

    model_config = SettingsConfigDict(env_file="../.env", extra="ignore")

    database_url: str = "postgresql+psycopg://yvoty:yvoty@localhost:5432/yvoty"
    plantnet_api_key: str = ""
    # Defaults to fake-plantnet; the real API (https://my-api.plantnet.org) must be opted in
    # explicitly.
    plantnet_base_url: str = "http://localhost:8100"
    plantnet_project: str = "all"
    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = "yvoty"
    s3_secret_key: str = "yvoty-secret"
    s3_bucket: str = "yvoty-photos"
    # Dev default only (>=32 bytes so PyJWT doesn't warn); set JWT_SECRET for anything real.
    jwt_secret: str = "dev-only-insecure-jwt-secret-change-me-0123456789"
    jwt_ttl_minutes: int = 60 * 24
    # Comma-separated browser origins allowed to call the API (Flutter web e2e/dev server).
    cors_origins: str = "http://127.0.0.1:8080,http://localhost:8080"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
