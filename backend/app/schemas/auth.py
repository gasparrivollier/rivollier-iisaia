from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.security import MAX_PASSWORD_BYTES

MIN_PASSWORD_CHARS = 8


def _strip(value: object) -> object:
    return value.strip() if isinstance(value, str) else value


class _EmailBody(BaseModel):
    email: EmailStr

    @field_validator("email", mode="before")
    @classmethod
    def _strip_email(cls, v: object) -> object:
        return _strip(v)

    @field_validator("email")
    @classmethod
    def _lower_email(cls, v: str) -> str:
        # The unique index is case-sensitive; store and look up one canonical form.
        return v.lower()


class RegisterRequest(_EmailBody):
    password: str = Field(min_length=MIN_PASSWORD_CHARS)
    display_name: str = Field(min_length=1, max_length=100)

    @field_validator("display_name", mode="before")
    @classmethod
    def _strip_display_name(cls, v: object) -> object:
        return _strip(v)

    @field_validator("password")
    @classmethod
    def _password_fits_bcrypt(cls, v: str) -> str:
        if len(v.encode()) > MAX_PASSWORD_BYTES:
            raise ValueError(f"password must be at most {MAX_PASSWORD_BYTES} bytes (UTF-8)")
        return v


class LoginRequest(_EmailBody):
    password: str = Field(min_length=1)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    display_name: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    user: UserOut
