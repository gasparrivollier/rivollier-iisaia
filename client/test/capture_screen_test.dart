import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yvoty/core/theme.dart';
import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/api/identify_dto.dart';
import 'package:yvoty/data/models/photo_shot.dart';
import 'package:yvoty/data/models/picked_photo.dart';
import 'package:yvoty/data/photo_picker.dart';
import 'package:yvoty/data/repositories/identify_repository.dart';
import 'package:yvoty/features/identify/capture_screen.dart';

class _Repo implements IdentifyRepository {
  _Repo({this.error});
  final ApiException? error;
  int calls = 0;
  List<PhotoShot> lastShots = const [];

  @override
  Future<IdentifyOutcome> identify({required List<PhotoShot> shots}) async {
    calls++;
    lastShots = shots;
    if (error != null) throw error!;
    return FakeIdentifyRepository().identify(shots: shots);
  }
}

PickedPhoto _photo(String name, {int size = 1}) =>
    PickedPhoto(name: name, bytes: Uint8List(size)..[0] = 1);

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

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

class _SlowPicker implements PhotoPicker {
  final pending = <Completer<PickedPhoto?>>[];
  int picks = 0;

  @override
  Future<PickedPhoto?> pick() {
    picks++;
    final c = Completer<PickedPhoto?>();
    pending.add(c);
    return c.future;
  }
}

bool _identifyEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('identifyButton'))).onPressed != null;

bool _pickEnabled(WidgetTester tester) =>
    tester.widget<GestureDetector>(find.byKey(const Key('pickPhotoButton'))).onTap != null;

void main() {
  testWidgets('identify is disabled until a photo is added', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo('a.png')), _Repo()));
    expect(_identifyEnabled(tester), isFalse);
    expect(find.text('0/5 photos'), findsOneWidget);
  });

  testWidgets('each pick adds a shot with organ auto and the count follows', (tester) async {
    final picker = FakePhotoPicker(queue: [_photo('a.png'), _photo('b.png')]);
    await tester.pumpWidget(_app(picker, _Repo()));
    await _pick(tester);
    await _pick(tester);
    expect(find.text('2/5 photos'), findsOneWidget);
    expect(find.text('a.png'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
    expect(_identifyEnabled(tester), isTrue);
  });

  testWidgets('the pick button is disabled at five shots', (tester) async {
    final picker = FakePhotoPicker(queue: [for (var i = 0; i < 5; i++) _photo('p$i.png')]);
    await tester.pumpWidget(_app(picker, _Repo()));
    for (var i = 0; i < 5; i++) {
      await _pick(tester);
    }
    expect(find.text('5/5 photos'), findsOneWidget);
    expect(_pickEnabled(tester), isFalse);
  });

  testWidgets('removing a shot frees a slot', (tester) async {
    final picker = FakePhotoPicker(queue: [for (var i = 0; i < 5; i++) _photo('p$i.png')]);
    await tester.pumpWidget(_app(picker, _Repo()));
    for (var i = 0; i < 5; i++) {
      await _pick(tester);
    }
    await _tapKey(tester, 'shot2Remove');
    expect(find.text('4/5 photos'), findsOneWidget);
    expect(find.text('p2.png'), findsNothing);
    expect(_pickEnabled(tester), isTrue);
  });

  testWidgets('removing a middle shot keeps the other shots paired with their organs',
      (tester) async {
    final repo = _Repo();
    final picker = FakePhotoPicker(queue: [_photo('a.png'), _photo('b.png'), _photo('c.png')]);
    await tester.pumpWidget(_app(picker, repo));
    for (var i = 0; i < 3; i++) {
      await _pick(tester);
    }
    await _tapKey(tester, 'shot0Organ-leaf');
    await _tapKey(tester, 'shot1Organ-flower');
    await _tapKey(tester, 'shot2Organ-bark');
    await _tapKey(tester, 'shot1Remove'); // drop b.png (flower)
    await _tapKey(tester, 'identifyButton');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(repo.lastShots.map((s) => (s.photo.name, s.organ)).toList(),
        [('a.png', 'leaf'), ('c.png', 'bark')]);
  });

  testWidgets('the organ chip shows which organ is selected and defaults to auto', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo('a.png')), _Repo()));
    await _pick(tester);
    bool selected(String organ) =>
        tester.widget<ChoiceChip>(find.byKey(Key('shot0Organ-$organ'))).selected;
    expect(selected('auto'), isTrue);
    await _tapKey(tester, 'shot0Organ-fruit');
    expect(selected('fruit'), isTrue);
    expect(selected('auto'), isFalse);
  });

  testWidgets('a rejected photo shows its message, adds nothing and keeps earlier shots',
      (tester) async {
    final picker = FakePhotoPicker(photo: _photo('ok.png'));
    await tester.pumpWidget(_app(picker, _Repo()));
    await _pick(tester);
    picker.rejection = 'tiny.png: Photo must be at least 800×800 pixels (this one is 100×100).';
    await _pick(tester);
    expect(tester.widget<Text>(find.byKey(const Key('identifyError'))).data,
        contains('tiny.png'));
    expect(find.text('1/5 photos'), findsOneWidget);
    expect(_identifyEnabled(tester), isTrue);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await tester.pumpWidget(_app(FakePhotoPicker(), _Repo()));
    await _pick(tester);
    expect(find.byKey(const Key('identifyError')), findsNothing);
    expect(find.text('0/5 photos'), findsOneWidget);
  });

  testWidgets('a photo that would push the total past 50 MB is refused', (tester) async {
    final picker = FakePhotoPicker(
        queue: [_photo('big1.png', size: 30000000), _photo('big2.png', size: 30000000)]);
    await tester.pumpWidget(_app(picker, _Repo()));
    await _pick(tester);
    await _pick(tester);
    expect(find.text('1/5 photos'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('identifyError'))).data, contains('50 MB'));
  });

  testWidgets('identify navigates to results on success and sends every shot', (tester) async {
    final repo = _Repo();
    final picker = FakePhotoPicker(queue: [_photo('a.png'), _photo('b.png')]);
    await tester.pumpWidget(_app(picker, repo));
    await _pick(tester);
    await _pick(tester);
    await _tapKey(tester, 'identifyButton');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(repo.calls, 1);
    expect(repo.lastShots, hasLength(2));
    expect(find.text('RESULTS PAGE'), findsOneWidget);
  });

  testWidgets('a 429 shows the limit message, keeps the shots and allows a retry', (tester) async {
    final repo = _Repo(error: ApiException(429, 'Daily identification limit reached'));
    await tester.pumpWidget(_app(FakePhotoPicker(photo: _photo('a.png')), repo));
    await _pick(tester);
    await _tapKey(tester, 'identifyButton');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identifyError')), findsOneWidget);
    expect(find.textContaining('limit'), findsOneWidget);
    expect(find.text('RESULTS PAGE'), findsNothing);
    expect(find.text('1/5 photos'), findsOneWidget);
    expect(_identifyEnabled(tester), isTrue);
  });

  testWidgets('while a pick is still decoding, add and identify are disabled', (tester) async {
    final picker = _SlowPicker();
    await tester.pumpWidget(_app(picker, _Repo()));
    await _pick(tester); // first pick starts and stays pending
    expect(_pickEnabled(tester), isFalse);
    expect(_identifyEnabled(tester), isFalse);

    await _pick(tester); // a second tap must not start another pick
    expect(picker.picks, 1);

    picker.pending.single.complete(_photo('a.png'));
    await tester.pumpAndSettle();
    expect(find.text('1/5 photos'), findsOneWidget);
    expect(_pickEnabled(tester), isTrue);
    expect(_identifyEnabled(tester), isTrue);
  });

  group('identifyErrorMessage', () {
    test('maps each failure class to a distinct, readable message', () {
      expect(identifyErrorMessage(ApiException(0, 'x')), contains('reach the server'));
      expect(identifyErrorMessage(ApiException(429, 'x')), contains('limit'));
      expect(identifyErrorMessage(ApiException(502, 'x')), contains('unavailable'));
      expect(identifyErrorMessage(ApiException(422, 'Photo 2: not an image')),
          'Photo 2: not an image');
      expect(identifyErrorMessage(ApiException(413, 'Photos total more than 50 MB')),
          'Photos total more than 50 MB');
      expect(
          identifyErrorMessage(ApiException(422, '[...]', fieldErrors: {'images': 'Field required'})),
          'Field required');
      expect(
          identifyErrorMessage(ApiException(422, '[...]', fieldErrors: {'organs': 'Field required'})),
          'Field required');
      expect(identifyErrorMessage(ApiException(500, 'x')), contains('500'));
    });
  });
}
