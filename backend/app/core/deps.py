from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.core.security import InvalidTokenError, decode_access_token
from app.db import get_db
from app.models import User

# auto_error=False: we raise our own uniform 401 instead of FastAPI's default 403/401 mix.
_bearer = HTTPBearer(auto_error=False)


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> User:
    if credentials is None:
        raise _unauthorized()
    try:
        user_id = decode_access_token(credentials.credentials, secret=settings.jwt_secret)
    except InvalidTokenError:
        raise _unauthorized() from None
    user = db.get(User, user_id)
    if user is None:
        raise _unauthorized()
    return user
