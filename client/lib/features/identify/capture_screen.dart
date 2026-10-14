import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/identify_repository.dart';

/// Port of design/yvoty-ui/01-Capture.dc.html.
///
/// The hero "viewfinder" is a static placeholder for now — real camera
/// capture needs the `image_picker`/`camera` plugin, which is backend-
/// integration work (architecture.md Phase 2/3) out of scope for this
/// UI-only pass. Tapping the shutter here just increments a mock shot count.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const _organs = ['flower', 'leaf', 'leaf'];
  int _shotCount = 3;
  bool _identifying = false;
  final _notesController = TextEditingController();

  void _addShot() {
    if (_shotCount >= 5) return;
    setState(() => _shotCount++);
  }

  Future<void> _identify() async {
    setState(() => _identifying = true);
    final repo = context.read<IdentifyRepository>();
    final results = await repo.identify(shotCount: _shotCount, notes: _notesController.text);
    if (!mounted) return;
    setState(() => _identifying = false);
    context.push('/results', extra: results);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 14, AppSpacing.xxl, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Specimen', style: context.yvotyType.serifStyle(fontSize: 19)),
                  const QuotaPill(label: '481 ids left today'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        'Field notes',
                        style: context.yvotyType.serifStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.inkSoft,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Flower or fruit shots identify best. Capture up to 5 angles of the same plant.',
                        style: TextStyle(fontSize: 13, color: AppColors.inkFaint, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _Viewfinder(),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          key: const Key('shutterButton'),
                          onTap: _addShot,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.paperRaised,
                              border: Border.all(color: AppColors.forest, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.forest),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'This session',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                          ),
                          Text(
                            '$_shotCount/5 photos',
                            style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < _shotCount;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.md),
                            child: Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: filled ? AppColors.forestSoft : null,
                                border: Border.all(
                                  color: AppColors.lineStrong,
                                  width: filled ? 1 : 1.5,
                                  style: filled ? BorderStyle.solid : BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: filled
                                  ? Text(
                                      _organs[i % _organs.length],
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                        color: AppColors.forest,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                          Text('optional', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Where you found it, smell, soil, anything odd…',
                          hintStyle: const TextStyle(color: AppColors.inkFaint),
                          filled: true,
                          fillColor: AppColors.paperRaised,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: AppColors.lineStrong),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(color: AppColors.forest),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, 26),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('identifyButton'),
                  onPressed: _identifying ? null : _identify,
                  child: _identifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper),
                        )
                      : const Text('Identify this plant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 397 / 343,
      child: Stack(
        children: [
          Positioned.fill(child: SketchPlaceholder(label: 'live viewfinder\n[ camera preview ]', borderRadius: 10)),
          Positioned(
            top: 12,
            right: 42,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                '⛶ Tap to expand',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.paper),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
