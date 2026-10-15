import 'package:flutter_test/flutter_test.dart';

import 'package:yvoty/main.dart';
import 'support/test_auth.dart';

void main() {
  testWidgets('Diary title exposes the diary-title semantics identifier', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(YvotyApp(auth: await signedInAuth()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('diary-title'), findsOneWidget);
    handle.dispose();
  });
}
