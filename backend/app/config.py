from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend settings. Read from env vars, then from the repo-root .env (git-ignored)."""

    model_config = SettingsConfigDict(env_file="../.env", extra="ignore")

    database_url: str = "postgresql+psycopg://yvoty:yvoty@localhost:5432/yvoty"
    plantnet_api_key: str = ""
    plantnet_base_url: str = "https://my-api.plantnet.org"
    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = "yvoty"
    s3_secret_key: str = "yvoty-secret"
    s3_bucket: str = "yvoty-photos"


@lru_cache
def get_settings() -> Settings:
    return Settings()
