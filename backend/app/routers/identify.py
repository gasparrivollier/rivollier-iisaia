import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.core.deps import get_current_user
from app.db import get_db
from app.models import User
from app.schemas.identify import IdentifyImageOut, IdentifyResponse, IdentifyResultOut
from app.services.identifications import StoredImage, persist_identification
from app.services.image_validation import (
    MAX_IMAGE_BYTES,
    ImageRejected,
    validate_image_set,
    validate_set_shape,
)
from app.services.plantnet_client import (
    ImagePart,
    PlantnetClient,
    PlantnetError,
    PlantnetNoPlant,
    PlantnetRateLimited,
    get_plantnet_client,
)
from app.services.storage import Storage, StorageError, get_storage

router = APIRouter(tags=["identify"])


@router.post("/identify", response_model=IdentifyResponse)
def identify(
    images: list[UploadFile],
    organs: Annotated[list[str], Form()],
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    plantnet: PlantnetClient = Depends(get_plantnet_client),
    storage: Storage = Depends(get_storage),
) -> IdentifyResponse:
    # Cheap shape checks first, so a hundred-file request never gets its bodies read.
    try:
        validate_set_shape(len(images), organs)
        # Read one byte past the cap so an oversize photo is detected without holding more than
        # that in memory (the multipart body itself is already received by the time this runs).
        blobs = [f.file.read(MAX_IMAGE_BYTES + 1) for f in images]
        photos = validate_image_set(blobs, organs)
    except ImageRejected as e:
        raise HTTPException(e.status_code, e.message) from None

    parts = [
        ImagePart(
            filename=f"photo{i}.{photo.ext}",
            content=data,
            content_type=photo.content_type,
            organ=organ,
        )
        for i, (data, photo, organ) in enumerate(zip(blobs, photos, organs, strict=True), start=1)
    ]

    # Pl@ntNet first: its failures (429, non-plant, outage) are common and must not leave
    # orphaned objects in storage.
    try:
        response = plantnet.identify(project=settings.plantnet_project, images=parts)
    except PlantnetRateLimited as e:
        headers = {"Retry-After": e.retry_after} if e.retry_after else None
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "Daily identification limit reached", headers=headers
        ) from None
    except PlantnetNoPlant:
        raise HTTPException(422, "No plant detected in these photos") from None
    except PlantnetError:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Identification service unavailable"
        ) from None

    stored: list[StoredImage] = []
    try:
        for part, photo in zip(parts, photos, strict=True):
            key = f"identifications/{user.id}/{uuid.uuid4().hex}.{photo.ext}"
            storage.put(key, part.content, part.content_type)
            stored.append(StoredImage(storage_key=key, organ=part.organ))
    except StorageError:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Photo storage unavailable") from None

    try:
        ident = persist_identification(
            db,
            user_id=user.id,
            project=settings.plantnet_project,
            response=response,
            images=stored,
        )
    except SQLAlchemyError:
        # An HTTPException keeps the CORS headers; an unhandled 500 would not, and the browser
        # would report it as "can't reach the server".
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "Could not save the identification"
        ) from None
    return IdentifyResponse(
        identification_id=ident.id,
        project=ident.project,
        best_match=ident.best_match,
        remaining_requests=ident.remaining_requests_at_call,
        images=[
            IdentifyImageOut(
                url=storage.presign(img.storage_key),
                organ=img.organ,
                predicted_organ=img.predicted_organ,
                predicted_organ_score=img.predicted_organ_score,
                sort_order=img.sort_order,
            )
            for img in ident.images
        ],
        results=[IdentifyResultOut.model_validate(r, from_attributes=True) for r in ident.results],
    )
