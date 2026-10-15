import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_client.dart';
import '../../data/models/photo_shot.dart';
import '../../data/photo_picker.dart';
import '../../data/photo_validation.dart';
import '../../data/repositories/identify_repository.dart';

/// User-facing text for a failed identify call.
String identifyErrorMessage(ApiException e) {
  switch (e.statusCode) {
    case 0:
      return "Can't reach the server. Check your connection and try again.";
    case 429:
      return 'Daily identification limit reached. Please try again later.';
    case 502:
      return 'The identification service is unavailable. Try again in a moment.';
    case 413:
    case 422:
      return e.fieldErrors['images'] ?? e.fieldErrors['organs'] ?? e.message;
    default:
      return 'Something went wrong (${e.statusCode}). Please try again.';
  }
}

/// Port of design/yvoty-ui/01-Capture.dc.html: up to five photos of one plant, each tagged
/// with the organ it shows. Field notes return in a later slice.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final List<PhotoShot> _shots = [];
  String? _error;
  bool _identifying = false;
  bool _picking = false;

  bool get _canAdd => _shots.length < kMaxShots && !_identifying && !_picking;
  int get _totalBytes => _shots.fold(0, (sum, s) => sum + s.photo.bytes.length);

  Future<void> _pick() async {
    if (!_canAdd) return;
    setState(() {
      _error = null;
      _picking = true;
    });
    try {
      final photo = await context.read<PhotoPicker>().pick();
      if (!mounted || photo == null || _shots.length >= kMaxShots) return;
      if (_totalBytes + photo.bytes.length > kMaxTotalPhotoBytes) {
        setState(() => _error = '${photo.name}: photos can total at most 50 MB.');
        return;
      }
      setState(() => _shots.add(PhotoShot(photo: photo)));
    } on PhotoRejected catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _setOrgan(int index, String organ) =>
      setState(() => _shots[index] = _shots[index].withOrgan(organ));

  void _remove(int index) => setState(() {
        _shots.removeAt(index);
        _error = null;
      });

  Future<void> _identify() async {
    if (_shots.isEmpty) return;
    setState(() {
      _identifying = true;
      _error = null;
    });
    try {
      final outcome = await context.read<IdentifyRepository>().identify(shots: List.of(_shots));
      if (!mounted) return;
      context.push('/results', extra: outcome);
    } on ApiException catch (e) {
      // A 401 also logs the user out (ApiClient.onUnauthorized); the router then leaves this screen.
      if (!mounted) return;
      setState(() => _error = identifyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _shots.isEmpty ? null : _shots.last;
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
                        'Flower or fruit shots identify best. Add up to 5 photos of the same plant '
                        '(JPEG or PNG, at least 800×800) and tag what each one shows.',
                        style: TextStyle(fontSize: 13, color: AppColors.inkFaint, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      AspectRatio(
                        aspectRatio: 397 / 343,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: latest == null
                              ? const SketchPlaceholder(
                                  label: 'no photo yet\n[ add one below ]', borderRadius: 10)
                              : Image.memory(
                                  latest.photo.bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Semantics(
                          identifier: 'pick-photo',
                          button: true,
                          enabled: _canAdd,
                          label: 'Add photo',
                          child: GestureDetector(
                            key: const Key('pickPhotoButton'),
                            onTap: _canAdd ? _pick : null,
                            child: Opacity(
                              opacity: _canAdd ? 1 : 0.4,
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
                                child: const Center(
                                  child: Icon(Icons.add_photo_alternate_outlined,
                                      size: 28, color: AppColors.forest),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'This session',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                          ),
                          Semantics(
                            identifier: 'shot-count',
                            container: true,
                            label: '${_shots.length}/$kMaxShots photos',
                            child: Text(
                              '${_shots.length}/$kMaxShots photos',
                              style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _shots.length; i++)
                        _ShotRow(
                          index: i,
                          shot: _shots[i],
                          enabled: !_identifying,
                          onOrgan: (organ) => _setOrgan(i, organ),
                          onRemove: () => _remove(i),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          identifier: 'identify-error',
                          liveRegion: true,
                          container: true,
                          label: _error,
                          child: Text(
                            _error!,
                            key: const Key('identifyError'),
                            style: const TextStyle(color: AppColors.terracotta, fontSize: 13.5),
                          ),
                        ),
                      ],
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
                child: Semantics(
                  identifier: 'identify-submit',
                  child: ElevatedButton(
                    key: const Key('identifyButton'),
                    onPressed: (_shots.isEmpty || _identifying || _picking) ? null : _identify,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({
    required this.index,
    required this.shot,
    required this.enabled,
    required this.onOrgan,
    required this.onRemove,
  });

  final int index;
  final PhotoShot shot;
  final bool enabled;
  final ValueChanged<String> onOrgan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Image.memory(
                shot.photo.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: AppColors.forestSoft),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shot.photo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final organ in kOrgans)
                      Semantics(
                        identifier: 'shot-$index-organ-$organ',
                        child: ChoiceChip(
                          key: Key('shot${index}Organ-$organ'),
                          label: Text(organ, style: const TextStyle(fontSize: 11.5)),
                          selected: shot.organ == organ,
                          visualDensity: VisualDensity.compact,
                          onSelected: enabled ? (_) => onOrgan(organ) : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            identifier: 'shot-$index-remove',
            child: IconButton(
              key: Key('shot${index}Remove'),
              tooltip: 'Remove photo',
              icon: const Icon(Icons.close, size: 20, color: AppColors.inkSoft),
              onPressed: enabled ? onRemove : null,
            ),
          ),
        ],
      ),
    );
  }
}
