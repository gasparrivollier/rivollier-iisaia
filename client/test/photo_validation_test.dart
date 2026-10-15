import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yvoty/data/photo_validation.dart';

Uint8List _png(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));
Uint8List _jpg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts an 800x800 PNG and a larger JPEG', () async {
    expect(await photoProblem(_png(800, 800)), isNull);
    expect(await photoProblem(_jpg(1000, 900)), isNull);
  });

  test('rejects images under 800px on either side and says the real size', () async {
    expect(await photoProblem(_png(799, 800)), contains('799'));
    expect(await photoProblem(_png(800, 799)), contains('800'));
  });

  test('rejects non-JPEG/PNG bytes by magic number', () async {
    expect(await photoProblem(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0])),
        contains('JPEG'));
    expect(await photoProblem(Uint8List(0)), contains('JPEG'));
  });

  test('rejects a PNG header followed by garbage', () async {
    final bytes = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(64, 7)]);
    expect(await photoProblem(bytes), contains('could not be read'));
  });

  test('rejects anything over 10 MB before decoding', () async {
    final big = Uint8List(kMaxPhotoBytes + 1)
      ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(await photoProblem(big), contains('10 MB'));
  });
}
