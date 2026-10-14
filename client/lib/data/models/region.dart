/// Mirrors the `provinces` reference table proposed in docs/architecture.md's
/// data-model addition for the region map feature. Geometry itself lives in
/// the bundled `assets/data/ar-lowpoly.geojson` asset, not here.
class Province {
  const Province({
    required this.name,
    required this.have,
    required this.total,
  });

  final String name;
  final int have;
  final int total;

  double get ratio => total == 0 ? 0 : have / total;
}

/// Mirrors the `region_species` reference table: one native species entry
/// for a province, plus whether the current user has already catalogued it.
class RegionSpecies {
  const RegionSpecies({
    required this.commonName,
    required this.scientificName,
    required this.have,
  });

  final String commonName;
  final String scientificName;
  final bool have;
}
