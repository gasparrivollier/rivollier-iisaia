import 'package:flutter_test/flutter_test.dart';

import 'package:yvoty/main.dart';

void main() {
  testWidgets('Diary title exposes the diary-title semantics identifier', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const YvotyApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('diary-title'), findsOneWidget);
    handle.dispose();
  });
}
