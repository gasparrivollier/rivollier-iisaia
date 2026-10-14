import '../models/identification_result.dart';
import '../models/plant.dart';

/// List/get/save/update-notes for a user's saved specimens. Real
/// implementation will call `GET/POST /garden` per docs/architecture.md;
/// this in-memory fake stands in until the backend exists.
abstract class PlantsRepository {
  List<Plant> list();
  Plant? get(String id);
  Plant save(IdentificationResult confirmed, {String nickname = ''});
  void updateNotes(String id, String notes);
}

class FakePlantsRepository implements PlantsRepository {
  final List<Plant> _plants = [
    Plant(
      id: 'p1',
      nickname: "Auntie's Jessamine",
      scientificName: 'Murraya paniculata',
      commonNames: 'Orange jessamine · Mock orange · Mirto',
      family: 'Rutaceae',
      genus: 'Murraya',
      confidencePct: 87,
      savedAt: DateTime(2026, 8, 21),
      notes:
          'Sidewalk hedge on Bulnes y Güemes, half shade. Flowers smell like '
          'orange blossom after rain — bees all over it.',
      photoLabels: const ['flower', 'leaf', 'bark'],
    ),
    Plant(
      id: 'p2',
      nickname: 'Balcony Basil',
      scientificName: 'Ocimum basilicum',
      commonNames: 'Sweet basil',
      family: 'Lamiaceae',
      genus: 'Ocimum',
      confidencePct: 92,
      savedAt: DateTime(2026, 7, 2),
      photoLabels: const ['leaf'],
    ),
    Plant(
      id: 'p3',
      nickname: 'Old Fig',
      scientificName: 'Ficus carica',
      commonNames: 'Common fig',
      family: 'Moraceae',
      genus: 'Ficus',
      confidencePct: 81,
      savedAt: DateTime(2026, 6, 14),
      photoLabels: const ['leaf', 'fruit'],
    ),
    Plant(
      id: 'p4',
      nickname: 'Porch Fern',
      scientificName: 'Nephrolepis exaltata',
      commonNames: 'Boston fern',
      family: 'Nephrolepidaceae',
      genus: 'Nephrolepis',
      confidencePct: 76,
      savedAt: DateTime(2026, 5, 30),
      photoLabels: const ['leaf'],
    ),
    Plant(
      id: 'p5',
      nickname: 'Sunday Rose',
      scientificName: 'Rosa chinensis',
      commonNames: 'China rose',
      family: 'Rosaceae',
      genus: 'Rosa',
      confidencePct: 90,
      savedAt: DateTime(2026, 5, 3),
      photoLabels: const ['flower'],
    ),
    Plant(
      id: 'p6',
      nickname: 'Trailside Mint',
      scientificName: 'Mentha spicata',
      commonNames: 'Spearmint',
      family: 'Lamiaceae',
      genus: 'Mentha',
      confidencePct: 84,
      savedAt: DateTime(2026, 4, 11),
      photoLabels: const ['leaf'],
    ),
  ];

  int _nextId = 7;

  @override
  List<Plant> list() => List.unmodifiable(_plants.reversed);

  @override
  Plant? get(String id) {
    for (final p in _plants) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Plant save(IdentificationResult confirmed, {String nickname = ''}) {
    final plant = Plant(
      id: 'p${_nextId++}',
      nickname: nickname.isEmpty ? confirmed.commonName : nickname,
      scientificName: confirmed.scientificName,
      commonNames: confirmed.commonName,
      family: confirmed.family,
      genus: confirmed.scientificName.split(' ').first,
      confidencePct: (confirmed.score * 100).round(),
      savedAt: DateTime.now(),
      photoLabels: const ['flower'],
    );
    _plants.add(plant);
    return plant;
  }

  @override
  void updateNotes(String id, String notes) {
    get(id)?.notes = notes;
  }
}
