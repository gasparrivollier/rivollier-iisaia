from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.models import Identification, IdentificationImage, IdentificationResult
from app.services.plantnet_client import PlantnetResponse


@dataclass(frozen=True)
class StoredImage:
    storage_key: str
    organ: str


def persist_identification(
    db: Session,
    *,
    user_id: int,
    project: str,
    response: PlantnetResponse,
    images: list[StoredImage],
) -> Identification:
    """Writes the identification, its images and every ranked candidate in one transaction.

    Pl@ntNet returns one predicted organ per submitted photo, in upload order, so photo *i*
    takes prediction *i*; if fewer come back the remaining photos get NULL.
    """
    ident = Identification(
        user_id=user_id,
        project=project,
        best_match=response.bestMatch,
        remaining_requests_at_call=response.remainingIdentificationRequests,
        plantnet_version=response.version,
    )
    for index, stored in enumerate(images):
        predicted = (
            response.predictedOrgans[index] if index < len(response.predictedOrgans) else None
        )
        ident.images.append(
            IdentificationImage(
                storage_key=stored.storage_key,
                organ=stored.organ,
                predicted_organ=predicted.organ if predicted else None,
                predicted_organ_score=predicted.score if predicted else None,
                sort_order=index,
            )
        )
    for rank, candidate in enumerate(response.results, start=1):
        species = candidate.species
        ident.results.append(
            IdentificationResult(
                rank=rank,
                score=candidate.score,
                scientific_name=species.scientificName,
                scientific_name_without_author=species.scientificNameWithoutAuthor,
                genus=species.genus.scientificNameWithoutAuthor if species.genus else None,
                family=species.family.scientificNameWithoutAuthor if species.family else None,
                common_names=list(species.commonNames),
                gbif_id=str(candidate.gbif.id) if candidate.gbif else None,
                powo_id=str(candidate.powo.id) if candidate.powo else None,
            )
        )
    db.add(ident)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return ident
