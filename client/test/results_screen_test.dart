import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yvoty/core/theme.dart';
import 'package:yvoty/data/api/identify_dto.dart';
import 'package:yvoty/data/models/identification_result.dart';
import 'package:yvoty/data/repositories/plants_repository.dart';
import 'package:yvoty/features/identify/results_screen.dart';

IdentifyOutcome _outcome({List<String?> predicted = const []}) => IdentifyOutcome(
      identificationId: 3,
      images: [for (final p in predicted) IdentifyImage(organ: 'auto', predictedOrgan: p)],
      results: const [
        IdentificationResult(
            rank: 1,
            scientificName: 'Murraya paniculata',
            commonName: 'Orange jessamine',
            family: 'Rutaceae',
            score: 0.89),
        IdentificationResult(
            rank: 2,
            scientificName: 'Citrus japonica',
            commonName: '',
            family: 'Rutaceae',
            score: 0.05),
      ],
    );

Widget _app(IdentifyOutcome o) => Provider<PlantsRepository>(
      create: (_) => FakePlantsRepository(),
      child: MaterialApp.router(
        theme: buildYvotyTheme(),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => ResultsScreen(outcome: o)),
        ]),
      ),
    );

void main() {
  testWidgets('lists the ranked candidates from the outcome', (tester) async {
    await tester.pumpWidget(_app(_outcome()));
    expect(find.text('Murraya paniculata'), findsOneWidget);
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('Best match'), findsOneWidget);
    expect(find.text('Citrus japonica'), findsOneWidget);
  });

  testWidgets('shows the organ banner only when the backend predicted one', (tester) async {
    await tester.pumpWidget(_app(_outcome(predicted: [null])));
    expect(find.textContaining('We detected'), findsNothing);

    await tester.pumpWidget(_app(_outcome(predicted: ['flower'])));
    await tester.pump();
    expect(find.textContaining('We detected a'), findsOneWidget);
    expect(find.textContaining('flower'), findsOneWidget);
    expect(find.textContaining('photo 1'), findsOneWidget);
  });

  testWidgets('the banner names the first photo that has a prediction', (tester) async {
    await tester.pumpWidget(_app(_outcome(predicted: [null, 'fruit', 'leaf'])));
    expect(find.textContaining('fruit'), findsOneWidget);
    expect(find.textContaining('photo 2'), findsOneWidget);
    expect(find.textContaining('leaf'), findsNothing);
  });

  testWidgets('a candidate without common names renders without an empty line', (tester) async {
    await tester.pumpWidget(_app(_outcome()));
    expect(find.text(''), findsNothing);
  });
}
