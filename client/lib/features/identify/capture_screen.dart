import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_client.dart';
import '../../data/models/picked_photo.dart';
import '../../data/photo_picker.dart';
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
      return e.fieldErrors['image'] ?? e.message;
    default:
      return 'Something went wrong (${e.statusCode}). Please try again.';
  }
}

/// Port of design/yvoty-ui/01-Capture.dc.html, reduced to a single chosen photo (slice 0.3).
/// Multi-photo sessions, organ tags and field notes return in later slices.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  PickedPhoto? _photo;
  String? _error;
  bool _identifying = false;

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final photo = await context.read<PhotoPicker>().pick();
      if (!mounted || photo == null) return;
      setState(() => _photo = photo);
    } on PhotoRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _photo = null;
        _error = e.message;
      });
    }
  }

  Future<void> _identify() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _identifying = true;
      _error = null;
    });
    try {
      final outcome = await context.read<IdentifyRepository>().identify(photo: photo);
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
    final photo = _photo;
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
                        'Flower or fruit shots identify best. Choose one clear photo of the plant '
                        '(JPEG or PNG, at least 800×800).',
                        style: TextStyle(fontSize: 13, color: AppColors.inkFaint, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        identifier: 'photo-preview',
                        container: true,
                        label: photo == null ? 'No photo chosen' : photo.name,
                        child: AspectRatio(
                          aspectRatio: 397 / 343,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: photo == null
                                ? const SketchPlaceholder(
                                    label: 'no photo yet\n[ choose one below ]', borderRadius: 10)
                                : Image.memory(
                                    photo.bytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Semantics(
                          identifier: 'pick-photo',
                          button: true,
                          label: 'Choose photo',
                          child: GestureDetector(
                            key: const Key('pickPhotoButton'),
                            onTap: _identifying ? null : _pick,
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
                                child: Icon(Icons.photo_library_outlined,
                                    size: 28, color: AppColors.forest),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          photo == null ? 'Tap to choose a photo' : photo.name,
                          style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 18),
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
                    onPressed: (_photo == null || _identifying) ? null : _identify,
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
