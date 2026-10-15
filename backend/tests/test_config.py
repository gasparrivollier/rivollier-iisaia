from app.config import Settings


def test_defaults_never_point_at_a_real_plantnet_key(monkeypatch):
    monkeypatch.delenv("PLANTNET_API_KEY", raising=False)
    s = Settings(_env_file=None)
    assert s.plantnet_api_key == ""
    assert s.database_url.startswith("postgresql+psycopg://")


def test_default_plantnet_url_is_the_fake_server(monkeypatch):
    monkeypatch.delenv("PLANTNET_BASE_URL", raising=False)
    assert Settings(_env_file=None).plantnet_base_url == "http://localhost:8100"


def test_env_vars_override_defaults(monkeypatch):
    monkeypatch.setenv("PLANTNET_BASE_URL", "http://fake-plantnet:8100")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://a:b@db:5432/x")
    s = Settings(_env_file=None)
    assert s.plantnet_base_url == "http://fake-plantnet:8100"
    assert s.database_url == "postgresql+psycopg://a:b@db:5432/x"


def test_auth_defaults_are_usable(monkeypatch):
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    s = Settings(_env_file=None)
    assert len(s.jwt_secret.encode()) >= 32
    assert s.jwt_ttl_minutes > 0
    assert s.cors_origin_list == ["http://127.0.0.1:8080", "http://localhost:8080"]


def test_cors_origins_parse_comma_separated(monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", " http://a:1 , ,http://b:2 ")
    assert Settings(_env_file=None).cors_origin_list == ["http://a:1", "http://b:2"]
