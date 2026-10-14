import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/region.dart';
import '../../data/repositories/region_repository.dart';
import 'province_geometry.dart';
import 'province_painter.dart';

const _assetPath = 'assets/data/ar-lowpoly.geojson';
const _mapAspectRatio = 390 / 560;

/// Port of design/yvoty-ui/05-Region-Map.html. The original used d3 +
/// topojson over CDN in a plain HTML page; here the same geojson asset is
/// rendered with a Flutter CustomPainter (see province_geometry.dart /
/// province_painter.dart) — the canvas-based approach architecture.md
/// already commits to for the animated garden view, applied here first.
class RegionMapScreen extends StatefulWidget {
  const RegionMapScreen({super.key});

  @override
  State<RegionMapScreen> createState() => _RegionMapScreenState();
}

class _RegionMapScreenState extends State<RegionMapScreen> {
  // Geometry is projected to the map's actual on-screen size, not a fixed
  // constant — CustomPaint is laid out by its parent (an AspectRatio inside
  // a scrollable column), so a mismatched projection size would render the
  // province shapes shrunk into a corner instead of filling the canvas.
  Size? _geometrySize;
  Future<ProvinceGeometry>? _geometryFuture;
  String _selected = 'Buenos Aires';

  Future<ProvinceGeometry> _geometryFor(Size size) {
    if (_geometrySize != size) {
      _geometrySize = size;
      _geometryFuture = ProvinceGeometry.load(_assetPath, size);
    }
    return _geometryFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RegionRepository>();
    final provinces = repo.listProvinces();
    final byName = {for (final p in provinces) p.name: p};
    final ranked = [...provinces]..sort((a, b) => b.ratio.compareTo(a.ratio));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Native species by province',
              backLabel: 'Diary',
              onBack: () => context.go('/'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Legend(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 8, AppSpacing.xxl, 0),
                      child: AspectRatio(
                        aspectRatio: _mapAspectRatio,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = constraints.biggest;
                            return FutureBuilder<ProvinceGeometry>(
                              future: _geometryFor(size),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final geometry = snapshot.data!;
                                return GestureDetector(
                                  onTapUp: (details) {
                                    final box = context.findRenderObject() as RenderBox;
                                    final local = box.globalToLocal(details.globalPosition);
                                    for (final shape in geometry.provinces) {
                                      if (shape.path.contains(local)) {
                                        setState(() => _selected = shape.name);
                                        break;
                                      }
                                    }
                                  },
                                  child: CustomPaint(
                                    size: size,
                                    painter: ProvinceMapPainter(
                                      geometry: geometry,
                                      ratioFor: (name) => byName[name]?.ratio ?? 0,
                                      labelFor: (name) => '${byName[name]?.have ?? 0}',
                                      selectedName: _selected,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
                      child: _DetailCard(province: byName[_selected]!, repo: repo),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 34),
                      child: _RankList(provinces: ranked.take(6).toList()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final swatches = [0xFFDAE3D6, 0xFF96BDA2, 0xFF54916B, 0xFF2C6B46];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 10, AppSpacing.xxl, 0),
      child: Row(
        children: [
          const Text('Catalogued', style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
          const SizedBox(width: 10),
          Row(
            children: swatches
                .map((c) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.forest),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'none → complete · tap a province',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.province, required this.repo});

  final Province province;
  final RegionRepository repo;

  @override
  Widget build(BuildContext context) {
    final species = repo.speciesFor(province.name);
    final pct = (province.ratio * 100).round();
    return JournalCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(province.name, style: context.yvotyType.serifStyle(fontSize: 18)),
              Text(
                '${province.have}/${province.total}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.forest),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ScoreBar(value: province.ratio),
          const SizedBox(height: 11),
          Text(
            '$pct% of native species catalogued here · sample list',
            style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 4),
          ...species.map((s) => _SpeciesRow(species: s)),
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.species});

  final RegionSpecies species;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: species.have ? AppColors.forest : null,
              shape: BoxShape.circle,
              border: species.have ? null : Border.all(color: AppColors.lineStrong, width: 1.5),
            ),
            child: Text(
              species.have ? '✓' : '?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: species.have ? AppColors.paper : AppColors.inkFaint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(species.commonName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(
                  species.scientificName,
                  style: context.yvotyType.serifStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.inkSoft, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankList extends StatelessWidget {
  const _RankList({required this.provinces});

  final List<Province> provinces;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your strongest provinces',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 4),
        ...provinces.map(
          (p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
                SizedBox(
                  width: 96,
                  child: ScoreBar(value: p.ratio),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${p.have}/${p.total}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
