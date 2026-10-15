from collections.abc import Iterator

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings


class Base(DeclarativeBase):
    pass


def make_engine(url: str) -> Engine:
    # connect_timeout keeps /health from hanging when Postgres is down.
    return create_engine(url, pool_pre_ping=True, connect_args={"connect_timeout": 3})


engine = make_engine(get_settings().database_url)  # lazy: does not connect until first use
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    with SessionLocal() as session:
        yield session
