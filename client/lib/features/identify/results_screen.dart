import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/identification_result.dart';
import '../../data/repositories/plants_repository.dart';

/// Port of design/yvoty-ui/02-Results.dc.html.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.candidates});

  final List<IdentificationResult> candidates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Results',
              backLabel: 'Retake',
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text('🌷', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12.5, color: AppColors.goldNoteText, height: 1.4),
                          children: [
                            TextSpan(text: 'We detected a '),
                            TextSpan(text: 'flower', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' in photo 1 — great signal for identification.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 0),
                itemBuilder: (context, i) => _CandidateTile(candidate: candidates[i]),
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
    return Container(
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
                Text(candidate.commonName, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                ScoreBar(value: candidate.score),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    PillTag(candidate.family),
                    if (candidate.isTop) const PillTag('Best match', variant: TagVariant.terracotta),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
