import 'dart:typed_data';

/// A photo the user chose, already read into memory (web has no file paths).
class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
