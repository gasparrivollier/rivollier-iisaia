import 'picked_photo.dart';

/// Organ tags Pl@ntNet accepts (docs/plantnet-api.md); `auto` lets it decide.
const List<String> kOrgans = ['auto', 'leaf', 'flower', 'fruit', 'bark'];

/// Photos allowed per identification (client and backend both enforce it).
const int kMaxShots = 5;

/// One photo in a capture session together with the organ the user tagged it as.
class PhotoShot {
  const PhotoShot({required this.photo, this.organ = 'auto'});

  final PickedPhoto photo;
  final String organ;

  PhotoShot withOrgan(String organ) => PhotoShot(photo: photo, organ: organ);
}
