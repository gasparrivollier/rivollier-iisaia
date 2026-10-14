import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/plant.dart';
import '../../data/repositories/plants_repository.dart';

/// Port of design/yvoty-ui/03-PlantDetail.dc.html.
class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({super.key, required this.plantId});

  final String plantId;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  bool _editing = false;
  late final TextEditingController _draftController;

  @override
  void initState() {
    super.initState();
    _draftController = TextEditingController();
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  void _startEditing(Plant plant) {
    _draftController.text = plant.notes;
    setState(() => _editing = true);
  }

  void _save(Plant plant, PlantsRepository repo) {
    repo.updateNotes(plant.id, _draftController.text.trim());
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlantsRepository>();
    final plant = repo.get(widget.plantId);

    if (plant == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(title: 'Specimen', backLabel: 'Diary', onBack: () => context.go('/')),
              const Expanded(child: Center(child: Text('Specimen not found'))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Specimen',
              backLabel: 'Diary',
              onBack: () => context.go('/'),
              trailing: const Text('Edit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.forest)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: JournalCard(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 292,
                                width: double.infinity,
                                child: SketchPlaceholder(label: 'Drop your best shot', borderRadius: 12),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          plant.nickname,
                                          style: context.yvotyType.serifStyle(fontSize: 22),
                                        ),
                                      ),
                                      const PillTag('Saved'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    plant.scientificName,
                                    style: context.yvotyType.serifStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.inkSoft,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plant.commonNames,
                                    style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, 0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.lg,
                        crossAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 2.6,
                        children: [
                          _Fact(k: 'Family', v: plant.family, serif: true),
                          _Fact(k: 'Genus', v: plant.genus, serif: true),
                          _Fact(k: 'Identified', v: _formatDate(plant.savedAt)),
                          _Fact(k: 'Match confidence', v: '${plant.confidencePct}%'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 0),
                      child: Divider(color: AppColors.line, height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Field notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                              Text(
                                _editing ? 'editing' : 'tap to edit',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_editing) ...[
                            TextField(
                              controller: _draftController,
                              maxLines: 4,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.5),
                              decoration: InputDecoration(
                                hintText: 'Where you found it, smell, soil, anything odd…',
                                filled: true,
                                fillColor: AppColors.paperRaised,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(color: AppColors.forest),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _editing = false),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                                ),
                                TextButton(
                                  onPressed: () => _save(plant, repo),
                                  child: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forest)),
                                ),
                              ],
                            ),
                          ] else
                            GestureDetector(
                              onTap: () => _startEditing(plant),
                              child: JournalCard(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                                child: Text(
                                  plant.notes.isEmpty ? 'Add a note from the field…' : plant.notes,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.55,
                                    color: plant.notes.isEmpty ? AppColors.inkFaint : AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Field photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: plant.photoLabels.length,
                              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                              itemBuilder: (context, i) => SizedBox(
                                width: 72,
                                child: SketchPlaceholder(label: plant.photoLabels[i], borderRadius: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.k, required this.v, this.serif = false});

  final String k;
  final String v;
  final bool serif;

  @override
  Widget build(BuildContext context) {
    return JournalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            k.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w600, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 4),
          Text(
            v,
            style: serif
                ? context.yvotyType.serifStyle(fontSize: 14, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic)
                : const TextStyle(fontSize: 14, color: AppColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
