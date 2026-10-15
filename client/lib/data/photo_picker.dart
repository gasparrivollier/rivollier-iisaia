import 'package:file_picker/file_picker.dart';

import 'models/picked_photo.dart';
import 'photo_validation.dart';

/// The chosen file cannot be identified; [message] is safe to show the user.
class PhotoRejected implements Exception {
  PhotoRejected(this.message);

  final String message;

  @override
  String toString() => 'PhotoRejected: $message';
}

/// Lets the user choose one photo. Returns null if they cancel; throws [PhotoRejected]
/// if the file fails the same checks the backend applies.
abstract class PhotoPicker {
  Future<PickedPhoto?> pick();
}

class FilePickerPhotoPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final problem = await photoProblem(bytes);
    if (problem != null) throw PhotoRejected('${file.name}: $problem');
    return PickedPhoto(name: file.name, bytes: bytes);
  }
}

/// Test double: returns the next of [queue] (else [photo]), throws [PhotoRejected] with
/// [rejection], or cancels (null).
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.photo, this.rejection, List<PickedPhoto>? queue}) : queue = queue ?? [];

  PickedPhoto? photo;
  String? rejection;
  final List<PickedPhoto> queue;
  int picks = 0;

  @override
  Future<PickedPhoto?> pick() async {
    picks++;
    if (rejection != null) throw PhotoRejected(rejection!);
    return queue.isNotEmpty ? queue.removeAt(0) : photo;
  }
}
