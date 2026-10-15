from pathlib import Path

import yaml

COMPOSE = Path(__file__).resolve().parents[2] / "compose.yaml"


def _services() -> dict:
    return yaml.safe_load(COMPOSE.read_text())["services"]


def test_backend_defaults_to_fake_plantnet():
    env = _services()["backend"]["environment"]
    assert env["PLANTNET_BASE_URL"] == "${PLANTNET_BASE_URL:-http://fake-plantnet:8100}"


def test_no_service_loads_env_file_wholesale():
    # .env holds the real Pl@ntNet key; services must only receive explicitly listed vars.
    assert all("env_file" not in svc for svc in _services().values())


def test_all_images_are_fully_qualified():
    for name, svc in _services().items():
        if "image" in svc:
            first = svc["image"].split("/")[0]
            assert "." in first, f"{name}: podman needs a registry-qualified image name"


def test_backend_receives_auth_settings():
    env = _services()["backend"]["environment"]
    assert env["JWT_SECRET"].startswith("${JWT_SECRET:-")
    assert "http://127.0.0.1:8080" in env["CORS_ORIGINS"]
