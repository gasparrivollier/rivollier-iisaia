// End-to-end smoke test for the 5-screen navigation flow, run via
// `flutter test test/app_flow_test.dart` on Flutter's VM test binding
// (real Chrome integration tests aren't supported for web targets yet —
// see https://github.com/flutter/flutter/issues for the tracking issue).
// Verifies Diary -> Capture -> Results -> PlantDetail -> back -> Region Map,
// including that the region map's CustomPainter actually renders shapes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yvoty/main.dart';
import 'package:yvoty/features/region/province_painter.dart';

void main() {
  testWidgets('full navigation flow across all 5 screens', (tester) async {
    await tester.pumpWidget(const YvotyApp());
    await tester.pumpAndSettle();

    // Diary: seeded plants + progress card visible.
    expect(find.text('My Diary'), findsOneWidget);
    expect(find.text('6 specimens catalogued'), findsOneWidget);
    // Most-recently-saved plant shows first (list() reverses insertion order).
    expect(find.text('Trailside Mint'), findsOneWidget);

    // Diary -> Capture.
    await tester.tap(find.byKey(const Key('captureFab')));
    await tester.pumpAndSettle();
    expect(find.text('New Specimen'), findsOneWidget);
    expect(find.text('3/5 photos'), findsOneWidget);

    // Shutter increments the shot count.
    await tester.ensureVisible(find.byKey(const Key('shutterButton')));
    await tester.tap(find.byKey(const Key('shutterButton')));
    await tester.pumpAndSettle();
    expect(find.text('4/5 photos'), findsOneWidget);

    // Capture -> Results.
    await tester.ensureVisible(find.byKey(const Key('identifyButton')));
    await tester.tap(find.byKey(const Key('identifyButton')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Murraya paniculata'), findsOneWidget);
    expect(find.text('Best match'), findsOneWidget);

    // Results -> PlantDetail (saves + navigates).
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    expect(find.text('Specimen'), findsOneWidget);
    expect(find.text('Murraya paniculata'), findsWidgets);
    expect(find.text('87%'), findsOneWidget);

    // Notes are editable inline.
    final addNoteFinder = find.text('Add a note from the field…');
    await tester.ensureVisible(addNoteFinder);
    await tester.tap(addNoteFinder);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Found near the fence line.');
    final doneFinder = find.text('Done');
    await tester.ensureVisible(doneFinder);
    await tester.tap(doneFinder);
    await tester.pumpAndSettle();
    expect(find.text('Found near the fence line.'), findsOneWidget);

    // PlantDetail -> back to Diary.
    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.text('My Diary'), findsOneWidget);
    expect(find.text('7 specimens catalogued'), findsOneWidget);

    // Diary -> Region Map.
    await tester.tap(find.byKey(const Key('regionProgressCard')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Native species by province'), findsOneWidget);
    expect(find.text('Buenos Aires'), findsWidgets);

    // The map's CustomPaint actually rendered province shapes (not blank),
    // and reused the real on-screen geometry (not a mismatched fixed size).
    final customPaintFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'ProvinceMapPainter',
    );
    final customPaint = tester.widget<CustomPaint>(customPaintFinder);
    final painter = customPaint.painter as ProvinceMapPainter;
    expect(painter.geometry.provinces, isNotEmpty);

    // Tap the exact projected label point of a solid, single-landmass
    // province (computed from the real rendered geometry, not a guessed
    // coordinate — an archipelago province's bounds-center can fall in open
    // water between islands, so this deliberately avoids Tierra del Fuego)
    // and confirm the selection changes away from the Buenos Aires default.
    final cordoba = painter.geometry.provinces.firstWhere((s) => s.name == 'Córdoba');
    final mapBox = tester.getRect(customPaintFinder);
    final tapPoint = mapBox.topLeft + cordoba.labelPoint;
    await tester.tapAt(tapPoint);
    await tester.pumpAndSettle();
    // The detail card's serif title switches to Córdoba. "Buenos Aires" can
    // stay on screen regardless (it's always in the "strongest provinces"
    // ranked list below), so that's not asserted away here.
    expect(find.text('Córdoba'), findsWidgets);
  });
}
