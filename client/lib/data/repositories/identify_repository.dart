import '../models/identification_result.dart';

/// Submits a capture session (photos + notes) and returns ranked candidates.
/// Real implementation will call `POST /identify` per docs/architecture.md;
/// this in-memory fake stands in until the backend exists (Phase B of the
/// front-end build plan / Phase 2 of architecture.md's backend build order).
abstract class IdentifyRepository {
  Future<List<IdentificationResult>> identify({
    required int shotCount,
    required String notes,
  });
}

class FakeIdentifyRepository implements IdentifyRepository {
  @override
  Future<List<IdentificationResult>> identify({
    required int shotCount,
    required String notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const [
      IdentificationResult(
        rank: 1,
        scientificName: 'Murraya paniculata',
        commonName: 'Orange jessamine',
        family: 'Rutaceae',
        score: 0.87,
        sketchLabel: 'sketch:\nflower',
      ),
      IdentificationResult(
        rank: 2,
        scientificName: 'Murraya koenigii',
        commonName: 'Curry leaf tree',
        family: 'Rutaceae',
        score: 0.06,
        sketchLabel: 'sketch:\nleaf',
      ),
      IdentificationResult(
        rank: 3,
        scientificName: 'Citrus japonica',
        commonName: 'Kumquat',
        family: 'Rutaceae',
        score: 0.03,
        sketchLabel: 'sketch:\nfruit',
      ),
      IdentificationResult(
        rank: 4,
        scientificName: 'Jasminum sambac',
        commonName: 'Arabian jasmine',
        family: 'Oleaceae',
        score: 0.02,
        sketchLabel: 'sketch:\nflower',
      ),
    ];
  }
}
