from sqlalchemy.orm import Session

from app.models import Identification, IdentificationImage, IdentificationResult
from app.services.plantnet_client import PlantnetResponse


def persist_identification(
    db: Session,
    *,
    user_id: int,
    project: str,
    response: PlantnetResponse,
    image_key: str,
    organ: str,
) -> Identification:
    """Writes the identification, its image and every ranked candidate in one transaction."""
    predicted = response.predictedOrgans[0] if response.predictedOrgans else None
    ident = Identification(
        user_id=user_id,
        project=project,
        best_match=response.bestMatch,
        remaining_requests_at_call=response.remainingIdentificationRequests,
        plantnet_version=response.version,
    )
    ident.images.append(
        IdentificationImage(
            storage_key=image_key,
            organ=organ,
            predicted_organ=predicted.organ if predicted else None,
            predicted_organ_score=predicted.score if predicted else None,
            sort_order=0,
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
