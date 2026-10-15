// Named params can't be private, so prefer_initializing_formals can't apply here.
// ignore_for_file: prefer_initializing_formals
import '../api/api_client.dart';
import '../api/identify_dto.dart';
import '../models/identification_result.dart';
import '../models/picked_photo.dart';

/// Submits one photo to `POST /identify` and returns the ranked candidates.
abstract class IdentifyRepository {
  Future<IdentifyOutcome> identify({required PickedPhoto photo});
}

class HttpIdentifyRepository implements IdentifyRepository {
  HttpIdentifyRepository(this._api, {required String? Function() readToken})
      : _readToken = readToken;

  final ApiClient _api;
  final String? Function() _readToken;

  /// Pl@ntNet can take a while; longer than ApiClient's 10 s default.
  static const _timeout = Duration(seconds: 45);

  @override
  Future<IdentifyOutcome> identify({required PickedPhoto photo}) async {
    final token = _readToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final json = await _api.postMultipart(
      '/identify',
      field: 'image',
      bytes: photo.bytes,
      filename: photo.name,
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
  Future<IdentifyOutcome> identify({required PickedPhoto photo}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const IdentifyOutcome(
      identificationId: 1,
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
