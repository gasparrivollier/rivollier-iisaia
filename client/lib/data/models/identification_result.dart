/// A single ranked candidate from a Pl@ntNet identify call.
/// Mirrors `results[]` in docs/plantnet-api.md's `/v2/identify` response.
class IdentificationResult {
  const IdentificationResult({
    required this.rank,
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.score,
    this.sketchLabel = 'sketch:\nplant',
  });

  final int rank;
  final String scientificName;
  final String commonName;
  final double score;
  final String family;
  final String sketchLabel;

  bool get isTop => rank == 1;
  String get scorePct => '${(score * 100).round()}%';
}
