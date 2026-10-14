"""Block until Postgres accepts connections (`python -m app.wait_for_db`, run before migrations)."""

import time

from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from app.config import get_settings
from app.db import make_engine


def wait_for_db(url: str, attempts: int = 30, delay: float = 1.0) -> None:
    engine = make_engine(url)
    try:
        for attempt in range(1, attempts + 1):
            try:
                with engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                return
            except OperationalError:
                if attempt == attempts:
                    raise
                print(f"wait_for_db: Postgres not ready (attempt {attempt}/{attempts})", flush=True)
                time.sleep(delay)
    finally:
        engine.dispose()


if __name__ == "__main__":
    wait_for_db(get_settings().database_url)
