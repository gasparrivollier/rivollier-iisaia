from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Identification(Base):
    """One row per Pl@ntNet /identify call, whether or not the user keeps the result."""

    __tablename__ = "identifications"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    project: Mapped[str] = mapped_column(String(64))
    best_match: Mapped[str | None] = mapped_column(String(255))
    remaining_requests_at_call: Mapped[int | None] = mapped_column(Integer)
    plantnet_version: Mapped[str | None] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    images: Mapped[list["IdentificationImage"]] = relationship(
        back_populates="identification",
        cascade="all, delete-orphan",
        order_by="IdentificationImage.sort_order",
    )
    results: Mapped[list["IdentificationResult"]] = relationship(
        back_populates="identification",
        cascade="all, delete-orphan",
        order_by="IdentificationResult.rank",
    )


class IdentificationImage(Base):
    __tablename__ = "identification_images"

    id: Mapped[int] = mapped_column(primary_key=True)
    identification_id: Mapped[int] = mapped_column(
        ForeignKey("identifications.id", ondelete="CASCADE"), index=True
    )
    storage_key: Mapped[str] = mapped_column(String(512))
    organ: Mapped[str] = mapped_column(String(16))
    predicted_organ: Mapped[str | None] = mapped_column(String(16))
    predicted_organ_score: Mapped[float | None] = mapped_column(Float)
    sort_order: Mapped[int] = mapped_column(Integer)

    identification: Mapped[Identification] = relationship(back_populates="images")


class IdentificationResult(Base):
    __tablename__ = "identification_results"

    id: Mapped[int] = mapped_column(primary_key=True)
    identification_id: Mapped[int] = mapped_column(
        ForeignKey("identifications.id", ondelete="CASCADE"), index=True
    )
    rank: Mapped[int] = mapped_column(Integer)
    score: Mapped[float] = mapped_column(Float)
    scientific_name: Mapped[str] = mapped_column(String(255))
    scientific_name_without_author: Mapped[str] = mapped_column(String(255))
    genus: Mapped[str | None] = mapped_column(String(255))
    family: Mapped[str | None] = mapped_column(String(255))
    common_names: Mapped[list[str]] = mapped_column(JSONB)
    gbif_id: Mapped[str | None] = mapped_column(String(32))
    powo_id: Mapped[str | None] = mapped_column(String(32))

    identification: Mapped[Identification] = relationship(back_populates="results")
