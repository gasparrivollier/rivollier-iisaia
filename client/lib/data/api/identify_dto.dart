import '../models/identification_result.dart';

/// One entry of `IdentifyResponse.images` in backend/openapi.json.
class IdentifyImage {
  const IdentifyImage({
    this.url,
    required this.organ,
    this.predictedOrgan,
    this.predictedOrganScore,
  });

  factory IdentifyImage.fromJson(Map<String, dynamic> json) => IdentifyImage(
        url: json['url'] as String,
        organ: json['organ'] as String,
        predictedOrgan: json['predicted_organ'] as String?,
        predictedOrganScore: (json['predicted_organ_score'] as num?)?.toDouble(),
      );

  /// Presigned URL of the stored photo; null for the in-memory fake.
  final String? url;

  /// The organ the user submitted for this photo.
  final String organ;

  /// What Pl@ntNet thinks the photo shows (may be e.g. `habit`).
  final String? predictedOrgan;
  final double? predictedOrganScore;
}

/// `IdentifyResponse` in backend/openapi.json (returned by POST /identify).
class IdentifyOutcome {
  const IdentifyOutcome({
    required this.identificationId,
    required this.results,
    this.images = const [],
    this.remainingRequests,
  });

  factory IdentifyOutcome.fromJson(Map<String, dynamic> json) => IdentifyOutcome(
        identificationId: json['identification_id'] as int,
        remainingRequests: json['remaining_requests'] as int?,
        images: [
          for (final i in json['images'] as List<dynamic>)
            IdentifyImage.fromJson(i as Map<String, dynamic>),
        ],
        results: [
          for (final r in json['results'] as List<dynamic>) _result(r as Map<String, dynamic>),
        ],
      );

  final int identificationId;
  final List<IdentificationResult> results;
  final List<IdentifyImage> images;
  final int? remainingRequests;

  /// The first photo's URL: all the UI shows of the photos for now.
  String? get imageUrl => images.isEmpty ? null : images.first.url;

  /// The first photo (1-based) Pl@ntNet predicted an organ for, if any.
  ({int photo, String organ})? get detectedOrgan {
    for (var i = 0; i < images.length; i++) {
      final organ = images[i].predictedOrgan;
      if (organ != null) return (photo: i + 1, organ: organ);
    }
    return null;
  }

  /// `IdentifyResultOut`. The UI shows the name without the author and the first common name.
  static IdentificationResult _result(Map<String, dynamic> r) {
    final commonNames = (r['common_names'] as List<dynamic>).cast<String>();
    return IdentificationResult(
      rank: r['rank'] as int,
      score: (r['score'] as num).toDouble(),
      scientificName: r['scientific_name_without_author'] as String,
      commonName: commonNames.isEmpty ? '' : commonNames.first,
      family: (r['family'] as String?) ?? '',
    );
  }
}
