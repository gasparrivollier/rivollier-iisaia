import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/identify_dto.dart';
import '../../data/models/identification_result.dart';
import '../../data/repositories/plants_repository.dart';

/// Port of design/yvoty-ui/02-Results.dc.html.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.outcome});

  final IdentifyOutcome outcome;

  List<IdentificationResult> get candidates => outcome.results;

  @override
  Widget build(BuildContext context) {
    final detected = outcome.detectedOrgan;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Results',
              backLabel: 'Retake',
              onBack: () => context.pop(),
            ),
            if (outcome.imageUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
                child: Semantics(
                  identifier: 'results-photo',
                  container: true,
                  label: 'Your photo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        outcome.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const SketchPlaceholder(label: 'photo\nunavailable'),
                      ),
                    ),
                  ),
                ),
              ),
            if (detected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('🌷', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.goldNoteText, height: 1.4),
                            children: [
                              const TextSpan(text: 'We detected a '),
                              TextSpan(
                                  text: detected.organ,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: ' in photo ${detected.photo}.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Semantics(
                identifier: 'results-list',
                container: true,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 0),
                  itemBuilder: (context, i) => _CandidateTile(candidate: candidates[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xs, AppSpacing.xxl, AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('saveButton'),
                  onPressed: () {
                    final best = candidates.firstWhere((c) => c.isTop, orElse: () => candidates.first);
                    final plant = context.read<PlantsRepository>().save(best);
                    context.go('/plants/${plant.id}');
                  },
                  child: const Text('Save best match to my garden'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate});

  final IdentificationResult candidate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'result-${candidate.rank}',
      container: true,
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: candidate.isTop
          ? BoxDecoration(
              border: Border.all(color: AppColors.forest, width: 1.5),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.forest.withValues(alpha: 0.05),
            )
          : const BoxDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, height: 64, child: SketchPlaceholder(label: candidate.sketchLabel)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        candidate.scientificName,
                        style: context.yvotyType.serifStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Text(
                      candidate.scorePct,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (candidate.commonName.isNotEmpty) ...[
                  Text(candidate.commonName,
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                  const SizedBox(height: 6),
                ],
                ScoreBar(value: candidate.score),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (candidate.family.isNotEmpty) PillTag(candidate.family),
                    if (candidate.isTop) const PillTag('Best match', variant: TagVariant.terracotta),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
