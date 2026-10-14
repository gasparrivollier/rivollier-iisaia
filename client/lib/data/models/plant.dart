/// A saved specimen. Mirrors the `plants` table from docs/architecture.md's
/// data model (joined with the confirmed identification_result for display).
class Plant {
  Plant({
    required this.id,
    required this.nickname,
    required this.scientificName,
    required this.commonNames,
    required this.family,
    required this.genus,
    required this.confidencePct,
    required this.savedAt,
    this.notes = '',
    List<String>? photoLabels,
  }) : photoLabels = photoLabels ?? const [];

  final String id;
  final String nickname;
  final String scientificName;
  final String commonNames;
  final String family;
  final String genus;
  final int confidencePct;
  final DateTime savedAt;
  String notes;
  final List<String> photoLabels;
}
