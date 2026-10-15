// Named params can't be private, so prefer_initializing_formals can't apply here.
// ignore_for_file: prefer_initializing_formals
import '../api/api_client.dart';
import '../api/identify_dto.dart';
import '../models/identification_result.dart';
import '../models/photo_shot.dart';

/// Submits one photo to `POST /identify` and returns the ranked candidates.
abstract class IdentifyRepository {
  Future<IdentifyOutcome> identify({required List<PhotoShot> shots});
}

class HttpIdentifyRepository implements IdentifyRepository {
  HttpIdentifyRepository(this._api, {required String? Function() readToken})
      : _readToken = readToken;

  final ApiClient _api;
  final String? Function() _readToken;

  /// Up to five photos plus Pl@ntNet; longer than ApiClient's 10 s default.
  static const _timeout = Duration(seconds: 60);

  @override
  Future<IdentifyOutcome> identify({required List<PhotoShot> shots}) async {
    final token = _readToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final json = await _api.postMultipart(
      '/identify',
      files: [
        for (final s in shots)
          UploadPart(field: 'images', bytes: s.photo.bytes, filename: s.photo.name),
      ],
      fields: [for (final s in shots) MapEntry('organs', s.organ)],
      token: token,
      timeout: _timeout,
    );
    try {
      return IdentifyOutcome.fromJson(json);
    } on TypeError {
      throw ApiException(200, 'Unexpected response from server');
    }
  }
}

/// In-memory double for widget tests (and the default when no backend is wired).
class FakeIdentifyRepository implements IdentifyRepository {
  @override
  Future<IdentifyOutcome> identify({required List<PhotoShot> shots}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const IdentifyOutcome(
      identificationId: 1,
      images: [IdentifyImage(organ: 'auto')],
      results: [
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
      ],
    );
  }
}
