# Import every model here so Alembic's autogenerate sees it via Base.metadata.
from app.models.identification import Identification, IdentificationImage, IdentificationResult
from app.models.user import User

__all__ = ["Identification", "IdentificationImage", "IdentificationResult", "User"]
