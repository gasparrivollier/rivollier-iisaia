import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yvoty/core/theme.dart';
import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/api/identify_dto.dart';
import 'package:yvoty/data/models/picked_photo.dart';
import 'package:yvoty/data/photo_picker.dart';
import 'package:yvoty/data/repositories/identify_repository.dart';
import 'package:yvoty/features/identify/capture_screen.dart';

class _Repo implements IdentifyRepository {
  _Repo({this.error});
  final ApiException? error;
  int calls = 0;

  @override
  Future<IdentifyOutcome> identify({required PickedPhoto photo}) async {
    calls++;
    if (error != null) throw error!;
    return FakeIdentifyRepository().identify(photo: photo);
  }
}

final _photo = PickedPhoto(name: 'leaf.png', bytes: Uint8List.fromList([1]));

Widget _app(PhotoPicker picker, IdentifyRepository repo) => MultiProvider(
      providers: [
        Provider<PhotoPicker>.value(value: picker),
        Provider<IdentifyRepository>.value(value: repo),
      ],
      child: MaterialApp.router(
        theme: buildYvotyTheme(),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const CaptureScreen()),
          GoRoute(path: '/results', builder: (_, _) => const Scaffold(body: Text('RESULTS PAGE'))),
        ]),
      ),
    );

Future<void> _pick(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('pickPhotoButton')));
  await tester.tap(find.byKey(const Key('pickPhotoButton')));
  await tester.pump();
}

bool _identifyEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('identifyButton'))).onPressed != null;

void main() {
  testWidgets('identify is disabled until a photo is chosen', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo), _Repo()));
    expect(_identifyEnabled(tester), isFalse);
  });

  testWidgets('choosing a photo enables identify and shows the file name', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo), _Repo()));
    await _pick(tester);
    expect(find.text('leaf.png'), findsOneWidget);
    expect(_identifyEnabled(tester), isTrue);
  });

  testWidgets('a rejected photo shows its message and keeps identify disabled', (tester) async {
    await tester.pumpWidget(_app(
        FakePhotoPicker(rejection: 'Photo must be at least 800×800 pixels (this one is 100×100).'),
        _Repo()));
    await _pick(tester);
    expect(tester.widget<Text>(find.byKey(const Key('identifyError'))).data, contains('at least 800'));
    expect(_identifyEnabled(tester), isFalse);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(), _Repo()));
    await _pick(tester);
    expect(find.byKey(const Key('identifyError')), findsNothing);
  });

  testWidgets('identify navigates to results on success', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo), repo));
    await _pick(tester);
    await tester.tap(find.byKey(const Key('identifyButton')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(repo.calls, 1);
    expect(find.text('RESULTS PAGE'), findsOneWidget);
  });

  testWidgets('a 429 shows the limit message and stays on the screen', (tester) async {
    final repo = _Repo(error: ApiException(429, 'Daily identification limit reached'));
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo), repo));
    await _pick(tester);
    await tester.tap(find.byKey(const Key('identifyButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identifyError')), findsOneWidget);
    expect(find.textContaining('limit'), findsOneWidget);
    expect(find.text('RESULTS PAGE'), findsNothing);
    expect(_identifyEnabled(tester), isTrue); // can retry
  });

  group('identifyErrorMessage', () {
    test('maps each failure class to a distinct, readable message', () {
      expect(identifyErrorMessage(ApiException(0, 'x')), contains('reach the server'));
      expect(identifyErrorMessage(ApiException(429, 'x')), contains('limit'));
      expect(identifyErrorMessage(ApiException(502, 'x')), contains('unavailable'));
      expect(identifyErrorMessage(ApiException(422, 'No plant detected in this photo')),
          'No plant detected in this photo');
      expect(
          identifyErrorMessage(ApiException(422, '[...]', fieldErrors: {'image': 'Field required'})),
          'Field required');
      expect(identifyErrorMessage(ApiException(500, 'x')), contains('500'));
    });
  });
}
