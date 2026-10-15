import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/models/picked_photo.dart';
import 'package:yvoty/data/repositories/identify_repository.dart';

const _json = {
  'identification_id': 12,
  'project': 'all',
  'best_match': 'Murraya paniculata (L.) Jack',
  'remaining_requests': 497,
  'image': {
    'url': 'http://127.0.0.1:9000/b/k.png?sig=1',
    'predicted_organ': 'flower',
    'predicted_organ_score': 0.77,
  },
  'results': [
    {
      'rank': 1,
      'score': 0.88926,
      'scientific_name': 'Murraya paniculata (L.) Jack',
      'scientific_name_without_author': 'Murraya paniculata',
      'genus': 'Murraya',
      'family': 'Rutaceae',
      'common_names': ['Orange Jasmine', 'Mock orange'],
      'gbif_id': '5421335',
      'powo_id': '774441-1',
    },
    {
      'rank': 2,
      'score': 0.05,
      'scientific_name': 'Citrus x',
      'scientific_name_without_author': 'Citrus x',
      'genus': null,
      'family': null,
      'common_names': [],
      'gbif_id': null,
      'powo_id': null,
    },
  ],
};

final _photo = PickedPhoto(name: 'leaf.png', bytes: Uint8List.fromList([1, 2, 3]));

HttpIdentifyRepository _repo(MockClientHandler h, {String? token = 'a.b.c'}) =>
    HttpIdentifyRepository(
      ApiClient(baseUrl: 'http://api.test', httpClient: MockClient(h)),
      readToken: () => token,
    );

void main() {
  test('identify uploads the photo with the bearer token and maps the response', () async {
    late http.Request sent;
    final repo = _repo((req) async {
      sent = req;
      return http.Response(jsonEncode(_json), 200);
    });

    final outcome = await repo.identify(photo: _photo);

    expect(sent.url.path, '/identify');
    expect(sent.headers['Authorization'], 'Bearer a.b.c');
    expect(sent.body, contains('name="image"'));
    expect(outcome.identificationId, 12);
    expect(outcome.imageUrl, 'http://127.0.0.1:9000/b/k.png?sig=1');
    expect(outcome.predictedOrgan, 'flower');
    expect(outcome.remainingRequests, 497);
    expect(outcome.results, hasLength(2));
    final top = outcome.results.first;
    expect([top.rank, top.scientificName, top.commonName, top.family, top.isTop],
        [1, 'Murraya paniculata', 'Orange Jasmine', 'Rutaceae', true]);
    expect(top.score, 0.88926);
    final other = outcome.results.last;
    expect([other.commonName, other.family], ['', '']);
  });

  test('no stored token fails with 401 without calling the network', () async {
    var calls = 0;
    final repo = _repo((_) async {
      calls++;
      return http.Response('{}', 200);
    }, token: null);

    await expectLater(repo.identify(photo: _photo),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(calls, 0);
  });

  test('a 2xx body with the wrong shape becomes ApiException', () async {
    final repo = _repo((_) async => http.Response(jsonEncode({'identification_id': 'x'}), 200));
    await expectLater(repo.identify(photo: _photo), throwsA(isA<ApiException>()));
  });

  test('server errors keep their status and message', () async {
    final repo =
        _repo((_) async => http.Response('{"detail":"No plant detected in this photo"}', 422));
    await expectLater(
      repo.identify(photo: _photo),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 422)
          .having((e) => e.message, 'message', 'No plant detected in this photo')),
    );
  });
}
