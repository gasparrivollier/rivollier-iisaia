"""create identifications, identification_images, identification_results

Revision ID: 0002_create_identifications
Revises: 0001_create_users
Create Date: 2026-10-14
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0002_create_identifications"
down_revision = "0001_create_users"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "identifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("project", sa.String(length=64), nullable=False),
        sa.Column("best_match", sa.String(length=255), nullable=True),
        sa.Column("remaining_requests_at_call", sa.Integer(), nullable=True),
        sa.Column("plantnet_version", sa.String(length=64), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_identifications_user_id", "identifications", ["user_id"])

    op.create_table(
        "identification_images",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "identification_id",
            sa.Integer(),
            sa.ForeignKey("identifications.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("organ", sa.String(length=16), nullable=False),
        sa.Column("predicted_organ", sa.String(length=16), nullable=True),
        sa.Column("predicted_organ_score", sa.Float(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
    )
    op.create_index(
        "ix_identification_images_identification_id", "identification_images", ["identification_id"]
    )

    op.create_table(
        "identification_results",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "identification_id",
            sa.Integer(),
            sa.ForeignKey("identifications.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("score", sa.Float(), nullable=False),
        sa.Column("scientific_name", sa.String(length=255), nullable=False),
        sa.Column("scientific_name_without_author", sa.String(length=255), nullable=False),
        sa.Column("genus", sa.String(length=255), nullable=True),
        sa.Column("family", sa.String(length=255), nullable=True),
        sa.Column("common_names", postgresql.JSONB(), nullable=False),
        sa.Column("gbif_id", sa.String(length=32), nullable=True),
        sa.Column("powo_id", sa.String(length=32), nullable=True),
    )
    op.create_index(
        "ix_identification_results_identification_id",
        "identification_results",
        ["identification_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_identification_results_identification_id", table_name="identification_results"
    )
    op.drop_table("identification_results")
    op.drop_index("ix_identification_images_identification_id", table_name="identification_images")
    op.drop_table("identification_images")
    op.drop_index("ix_identifications_user_id", table_name="identifications")
    op.drop_table("identifications")
