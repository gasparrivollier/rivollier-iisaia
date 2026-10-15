import '../models/identification_result.dart';

/// `IdentifyResponse` in backend/openapi.json (returned by POST /identify).
class IdentifyOutcome {
  const IdentifyOutcome({
    required this.identificationId,
    required this.results,
    this.imageUrl,
    this.predictedOrgan,
    this.remainingRequests,
  });

  factory IdentifyOutcome.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as Map<String, dynamic>;
    return IdentifyOutcome(
      identificationId: json['identification_id'] as int,
      imageUrl: image['url'] as String,
      predictedOrgan: image['predicted_organ'] as String?,
      remainingRequests: json['remaining_requests'] as int?,
      results: [
        for (final r in json['results'] as List<dynamic>) _result(r as Map<String, dynamic>),
      ],
    );
  }

  final int identificationId;
  final List<IdentificationResult> results;

  /// Presigned URL of the stored photo; null for the in-memory fake.
  final String? imageUrl;
  final String? predictedOrgan;
  final int? remainingRequests;

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
