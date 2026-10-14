# Import every model here so Alembic's autogenerate sees it via Base.metadata.
from app.models.user import User

__all__ = ["User"]
