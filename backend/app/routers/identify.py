import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.core.deps import get_current_user
from app.db import get_db
from app.models import User
from app.schemas.identify import IdentifyImageOut, IdentifyResponse, IdentifyResultOut
from app.services.identifications import persist_identification
from app.services.image_validation import MAX_IMAGE_BYTES, ImageRejected, validate_image
from app.services.plantnet_client import (
    PlantnetClient,
    PlantnetError,
    PlantnetNoPlant,
    PlantnetRateLimited,
    get_plantnet_client,
)
from app.services.storage import Storage, StorageError, get_storage

router = APIRouter(tags=["identify"])

# Slice 0.3 sends one photo with no organ hint; 0.4 adds real organ tags.
_ORGAN = "auto"


@router.post("/identify", response_model=IdentifyResponse)
def identify(
    image: UploadFile,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    plantnet: PlantnetClient = Depends(get_plantnet_client),
    storage: Storage = Depends(get_storage),
) -> IdentifyResponse:
    # Read one byte past the cap so an oversize body is detected without buffering all of it.
    data = image.file.read(MAX_IMAGE_BYTES + 1)
    try:
        photo = validate_image(data)
    except ImageRejected as e:
        raise HTTPException(e.status_code, e.message) from None

    # Pl@ntNet first: its failures (429, non-plant, outage) are common and must not leave
    # orphaned objects in storage.
    try:
        response = plantnet.identify(
            project=settings.plantnet_project,
            filename=f"photo.{photo.ext}",
            content=data,
            content_type=photo.content_type,
            organ=_ORGAN,
        )
    except PlantnetRateLimited as e:
        headers = {"Retry-After": e.retry_after} if e.retry_after else None
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "Daily identification limit reached", headers=headers
        ) from None
    except PlantnetNoPlant:
        raise HTTPException(422, "No plant detected in this photo") from None
    except PlantnetError:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Identification service unavailable"
        ) from None

    key = f"identifications/{user.id}/{uuid.uuid4().hex}.{photo.ext}"
    try:
        storage.put(key, data, photo.content_type)
    except StorageError:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Photo storage unavailable") from None

    ident = persist_identification(
        db,
        user_id=user.id,
        project=settings.plantnet_project,
        response=response,
        image_key=key,
        organ=_ORGAN,
    )
    stored = ident.images[0]
    return IdentifyResponse(
        identification_id=ident.id,
        project=ident.project,
        best_match=ident.best_match,
        remaining_requests=ident.remaining_requests_at_call,
        image=IdentifyImageOut(
            url=storage.presign(stored.storage_key),
            predicted_organ=stored.predicted_organ,
            predicted_organ_score=stored.predicted_organ_score,
        ),
        results=[IdentifyResultOut.model_validate(r, from_attributes=True) for r in ident.results],
    )
