from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import IntegrityError

pytestmark = pytest.mark.integration

BACKEND_DIR = Path(__file__).parents[2]


def _cfg(url: str) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    cfg.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return cfg


@pytest.fixture
def migrated(test_db_url):
    cfg = _cfg(test_db_url)
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    engine = create_engine(test_db_url)
    yield engine
    engine.dispose()
    command.downgrade(cfg, "base")


def test_upgrade_creates_users_table(migrated):
    cols = {c["name"] for c in inspect(migrated).get_columns("users")}
    assert cols == {"id", "email", "password_hash", "display_name", "created_at"}


def test_users_email_is_unique(migrated):
    insert = text("INSERT INTO users (email, password_hash, display_name) VALUES (:e, 'h', 'n')")
    with migrated.begin() as conn:
        conn.execute(insert, {"e": "a@example.com"})
    with pytest.raises(IntegrityError), migrated.begin() as conn:
        conn.execute(insert, {"e": "a@example.com"})


def test_created_at_defaults_to_now(migrated):
    with migrated.begin() as conn:
        conn.execute(
            text("INSERT INTO users (email, password_hash, display_name) VALUES ('b@x.io','h','n')")
        )
        created = conn.execute(text("SELECT created_at FROM users")).scalar_one()
    assert created is not None and created.tzinfo is not None


def test_upgrade_head_twice_is_noop(migrated, test_db_url):
    command.upgrade(_cfg(test_db_url), "head")  # second run on an up-to-date DB must not fail
    assert "users" in inspect(migrated).get_table_names()
