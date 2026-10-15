import pytest
from sqlalchemy.exc import OperationalError

from app.wait_for_db import wait_for_db

UNREACHABLE = "postgresql+psycopg://x:y@127.0.0.1:1/nope"


def test_wait_for_db_gives_up_after_attempts():
    with pytest.raises(OperationalError):
        wait_for_db(UNREACHABLE, attempts=2, delay=0)


@pytest.mark.integration
def test_wait_for_db_returns_when_db_is_up(test_db_url):
    wait_for_db(test_db_url, attempts=3, delay=0)  # no exception
