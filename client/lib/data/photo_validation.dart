import 'dart:typed_data';
import 'dart:ui' as ui;

/// Mirrors backend/app/services/image_validation.py so a photo that would be rejected
/// never leaves the browser (a rejected Pl@ntNet call still costs a credit).
const int kMaxPhotoBytes = 10 * 1024 * 1024;
const int kMinPhotoSide = 800;

/// Pl@ntNet rejects requests over 50 MB in total (mirrors the backend's MAX_TOTAL_BYTES).
const int kMaxTotalPhotoBytes = 50 * 1000 * 1000;

const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const _jpegMagic = [0xFF, 0xD8, 0xFF];

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// A user-facing reason this photo cannot be identified, or null if it can be sent.
Future<String?> photoProblem(Uint8List bytes) async {
  if (bytes.length > kMaxPhotoBytes) return 'Photo is larger than 10 MB.';
  if (!_startsWith(bytes, _pngMagic) && !_startsWith(bytes, _jpegMagic)) {
    return 'Only JPEG and PNG photos are supported.';
  }
  int width, height;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    width = frame.image.width;
    height = frame.image.height;
    frame.image.dispose();
    codec.dispose();
  } catch (_) {
    return 'That file could not be read as an image.';
  }
  if (width < kMinPhotoSide || height < kMinPhotoSide) {
    return 'Photo must be at least $kMinPhotoSide×$kMinPhotoSide pixels '
        '(this one is $width×$height).';
  }
  return null;
}
