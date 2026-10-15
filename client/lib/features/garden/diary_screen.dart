import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/plant.dart';
import '../../data/repositories/plants_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../auth/auth_controller.dart';

/// Port of design/yvoty-ui/04-Diary.dc.html — the app's home/landing screen.
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plants = context.read<PlantsRepository>().list();
    final provinces = context.read<RegionRepository>().listProvinces();
    final collected = provinces.fold<int>(0, (sum, p) => sum + p.have);
    final total = provinces.fold<int>(0, (sum, p) => sum + p.total);
    final progressPct = total == 0 ? 0.0 : collected / total;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(count: plants.length)),
                SliverToBoxAdapter(
                  child: _ProgressCard(
                    collected: collected,
                    total: total,
                    progressPct: progressPct,
                  ),
                ),
                SliverToBoxAdapter(child: _SearchBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    90,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.lg,
                      crossAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _PlantCard(plant: plants[i]),
                      childCount: plants.length,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 22,
              bottom: 26,
              child: FloatingActionButton(
                key: const Key('captureFab'),
                onPressed: () => context.push('/capture'),
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.paper,
                child: const Icon(Icons.add, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 14, AppSpacing.xxl, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                identifier: 'diary-title',
                child: Text('My Diary', style: context.yvotyType.serifStyle(fontSize: 21)),
              ),
              const SizedBox(height: 2),
              Text(
                '$count specimens catalogued',
                style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
              ),
            ],
          ),
          Row(
            children: [
              const QuotaPill(label: '481 ids left'),
              Semantics(
                identifier: 'logout',
                child: IconButton(
                  key: const Key('logoutButton'),
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout, size: 20),
                  color: AppColors.inkSoft,
                  onPressed: () => context.read<AuthController>().logout(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.collected, required this.total, required this.progressPct});

  final int collected;
  final int total;
  final double progressPct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
      child: JournalCard(
        key: const Key('regionProgressCard'),
        onTap: () => context.push('/region'),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collection progress  ›',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                ),
                Text(
                  '$collected/$total',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ScoreBar(value: progressPct),
            const SizedBox(height: 9),
            Text(
              '${(progressPct * 100).round()}% of your region\'s common species catalogued',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paperRaised,
          border: Border.all(color: AppColors.lineStrong),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 18, color: AppColors.inkFaint),
            SizedBox(width: 10),
            Text('Search your garden…', style: TextStyle(fontSize: 14, color: AppColors.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return JournalCard(
      onTap: () => context.push('/plants/${plant.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: SketchPlaceholder(label: 'sketch', borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.nickname,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  plant.scientificName,
                  style: context.yvotyType.serifStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
