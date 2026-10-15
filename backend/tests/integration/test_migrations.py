import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import IntegrityError

import app.models  # noqa: F401  (registers every model on Base.metadata)
from app.db import Base
from tests.integration.alembic_helpers import alembic_cfg

pytestmark = pytest.mark.integration


@pytest.fixture
def migrated(test_db_url):
    cfg = alembic_cfg(test_db_url)
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
    command.upgrade(
        alembic_cfg(test_db_url), "head"
    )  # second run on an up-to-date DB must not fail
    assert "users" in inspect(migrated).get_table_names()


def test_upgrade_creates_identification_tables(migrated):
    insp = inspect(migrated)
    assert {c["name"] for c in insp.get_columns("identifications")} == {
        "id",
        "user_id",
        "project",
        "best_match",
        "remaining_requests_at_call",
        "plantnet_version",
        "created_at",
    }
    assert {c["name"] for c in insp.get_columns("identification_images")} == {
        "id",
        "identification_id",
        "storage_key",
        "organ",
        "predicted_organ",
        "predicted_organ_score",
        "sort_order",
    }
    assert {c["name"] for c in insp.get_columns("identification_results")} == {
        "id",
        "identification_id",
        "rank",
        "score",
        "scientific_name",
        "scientific_name_without_author",
        "genus",
        "family",
        "common_names",
        "gbif_id",
        "powo_id",
    }


def test_models_match_the_migrations(migrated):
    with migrated.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == []


def test_deleting_a_user_cascades_to_identifications(migrated):
    with migrated.begin() as conn:
        uid = conn.execute(
            text(
                "INSERT INTO users (email, password_hash, display_name) "
                "VALUES ('c@x.io','h','n') RETURNING id"
            )
        ).scalar_one()
        iid = conn.execute(
            text("INSERT INTO identifications (user_id, project) VALUES (:u,'all') RETURNING id"),
            {"u": uid},
        ).scalar_one()
        conn.execute(
            text(
                "INSERT INTO identification_images (identification_id, storage_key, organ,"
                " sort_order) VALUES (:i,'k','auto',0)"
            ),
            {"i": iid},
        )
        conn.execute(
            text(
                "INSERT INTO identification_results (identification_id, rank, score,"
                " scientific_name, scientific_name_without_author, common_names)"
                " VALUES (:i,1,0.5,'A b L.','A b','[]')"
            ),
            {"i": iid},
        )
        conn.execute(text("DELETE FROM users WHERE id = :u"), {"u": uid})
        for table in ("identifications", "identification_images", "identification_results"):
            assert conn.execute(text(f"SELECT count(*) FROM {table}")).scalar_one() == 0
