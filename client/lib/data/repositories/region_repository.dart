import '../models/region.dart';

/// Lists provinces + per-province native species coverage. Real
/// implementation will query the `provinces`/`region_species` reference
/// tables proposed in docs/architecture.md's data-model addition, joined
/// against the user's `plants`; this in-memory fake is seeded from the
/// sample data in design/yvoty-ui/05-Region-Map.html.
abstract class RegionRepository {
  List<Province> listProvinces();
  List<RegionSpecies> speciesFor(String provinceName);
}

class FakeRegionRepository implements RegionRepository {
  static const _provinces = [
    Province(name: 'Jujuy', have: 9, total: 41),
    Province(name: 'Salta', have: 14, total: 58),
    Province(name: 'Formosa', have: 3, total: 44),
    Province(name: 'Chaco', have: 5, total: 46),
    Province(name: 'Tucumán', have: 11, total: 39),
    Province(name: 'Misiones', have: 21, total: 62),
    Province(name: 'Catamarca', have: 4, total: 37),
    Province(name: 'Santiago del Estero', have: 2, total: 35),
    Province(name: 'Corrientes', have: 7, total: 48),
    Province(name: 'La Rioja', have: 3, total: 33),
    Province(name: 'Santa Fe', have: 12, total: 40),
    Province(name: 'San Juan', have: 5, total: 31),
    Province(name: 'Entre Ríos', have: 10, total: 42),
    Province(name: 'Córdoba', have: 19, total: 45),
    Province(name: 'San Luis', have: 6, total: 30),
    Province(name: 'Ciudad de Buenos Aires', have: 24, total: 26),
    Province(name: 'Mendoza', have: 13, total: 38),
    Province(name: 'Buenos Aires', have: 28, total: 52),
    Province(name: 'La Pampa', have: 4, total: 29),
    Province(name: 'Neuquén', have: 8, total: 36),
    Province(name: 'Río Negro', have: 6, total: 34),
    Province(name: 'Chubut', have: 5, total: 32),
    Province(name: 'Santa Cruz', have: 2, total: 27),
    Province(name: 'Tierra del Fuego', have: 1, total: 18),
  ];

  static const _species = <String, List<RegionSpecies>>{
    'Misiones': [
      RegionSpecies(commonName: 'Pino paraná', scientificName: 'Araucaria angustifolia', have: true),
      RegionSpecies(commonName: 'Cedro misionero', scientificName: 'Cedrela fissilis', have: true),
      RegionSpecies(commonName: 'Palo rosa', scientificName: 'Aspidosperma polyneuron', have: false),
      RegionSpecies(commonName: 'Yerba mate', scientificName: 'Ilex paraguariensis', have: true),
      RegionSpecies(commonName: 'Guatambú blanco', scientificName: 'Balfourodendron riedelianum', have: false),
    ],
    'Buenos Aires': [
      RegionSpecies(commonName: 'Ceibo', scientificName: 'Erythrina crista-galli', have: true),
      RegionSpecies(commonName: 'Tala', scientificName: 'Celtis tala', have: true),
      RegionSpecies(commonName: 'Coronillo', scientificName: 'Scutia buxifolia', have: true),
      RegionSpecies(commonName: 'Cortadera', scientificName: 'Cortaderia selloana', have: false),
      RegionSpecies(commonName: 'Seibo de flor blanca', scientificName: 'Sesbania punicea', have: false),
    ],
    'Salta': [
      RegionSpecies(commonName: 'Cebil colorado', scientificName: 'Anadenanthera colubrina', have: true),
      RegionSpecies(commonName: 'Nogal criollo', scientificName: 'Juglans australis', have: false),
      RegionSpecies(commonName: 'Pino del cerro', scientificName: 'Podocarpus parlatorei', have: false),
      RegionSpecies(commonName: 'Cardón', scientificName: 'Echinopsis atacamensis', have: true),
      RegionSpecies(commonName: 'Tipa blanca', scientificName: 'Tipuana tipu', have: true),
    ],
    'Neuquén': [
      RegionSpecies(commonName: 'Ñire', scientificName: 'Nothofagus antarctica', have: true),
      RegionSpecies(commonName: 'Ciprés de la cordillera', scientificName: 'Austrocedrus chilensis', have: true),
      RegionSpecies(commonName: 'Araucaria', scientificName: 'Araucaria araucana', have: false),
      RegionSpecies(commonName: 'Coihue', scientificName: 'Nothofagus dombeyi', have: false),
      RegionSpecies(commonName: 'Notro', scientificName: 'Embothrium coccineum', have: false),
    ],
    'Tierra del Fuego': [
      RegionSpecies(commonName: 'Lenga', scientificName: 'Nothofagus pumilio', have: true),
      RegionSpecies(commonName: 'Guindo', scientificName: 'Nothofagus betuloides', have: false),
      RegionSpecies(commonName: 'Canelo', scientificName: 'Drimys winteri', have: false),
      RegionSpecies(commonName: 'Calafate', scientificName: 'Berberis microphylla', have: false),
      RegionSpecies(commonName: 'Frutilla del diablo', scientificName: 'Gunnera magellanica', have: false),
    ],
    'Mendoza': [
      RegionSpecies(commonName: 'Algarrobo dulce', scientificName: 'Neltuma flexuosa', have: true),
      RegionSpecies(commonName: 'Jarilla', scientificName: 'Larrea divaricata', have: true),
      RegionSpecies(commonName: 'Chañar', scientificName: 'Geoffroea decorticans', have: false),
      RegionSpecies(commonName: 'Retamo', scientificName: 'Bulnesia retama', have: false),
      RegionSpecies(commonName: 'Molle de beber', scientificName: 'Lithraea molleoides', have: false),
    ],
  };

  static const _defaultSpecies = [
    RegionSpecies(commonName: 'Ceibo', scientificName: 'Erythrina crista-galli', have: true),
    RegionSpecies(commonName: 'Jacarandá', scientificName: 'Jacaranda mimosifolia', have: true),
    RegionSpecies(commonName: 'Aguaribay', scientificName: 'Schinus molle', have: false),
    RegionSpecies(commonName: 'Chañar', scientificName: 'Geoffroea decorticans', have: false),
    RegionSpecies(commonName: 'Algarrobo blanco', scientificName: 'Neltuma alba', have: false),
  ];

  @override
  List<Province> listProvinces() => _provinces;

  @override
  List<RegionSpecies> speciesFor(String provinceName) =>
      _species[provinceName] ?? _defaultSpecies;
}
