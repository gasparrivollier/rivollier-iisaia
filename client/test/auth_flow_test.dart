import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvoty/data/repositories/auth_repository.dart';
import 'package:yvoty/main.dart';

import 'package:yvoty/data/api/api_client.dart';
import 'package:yvoty/data/api/auth_dto.dart';
import 'package:yvoty/features/auth/auth_widgets.dart';

import 'support/test_auth.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

class _Rejects422 extends FakeAuthRepository {
  @override
  Future<AuthSession> register(
          {required String email, required String password, required String displayName}) =>
      throw ApiException(422, 'invalid', fieldErrors: {'email': 'value is not a valid email address'});
}

void main() {
  testWidgets('signed-out users land on login instead of the Diary', (tester) async {
    final handle = tester.ensureSemantics();
    final auth = await signedOutAuth();
    await tester.pumpWidget(YvotyApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('login-title'), findsOneWidget);
    expect(find.text('My Diary'), findsNothing);
    handle.dispose();
  });

  testWidgets('register → Diary → sign out → login → Diary', (tester) async {
    final auth = await signedOutAuth();
    await tester.pumpWidget(YvotyApp(auth: auth));
    await tester.pumpAndSettle();

    await _tap(tester, 'goToRegister');
    await tester.enterText(find.byKey(const Key('registerDisplayName')), 'Pat');
    await tester.enterText(find.byKey(const Key('registerEmail')), 'pat@example.com');
    await tester.enterText(find.byKey(const Key('registerPassword')), 'correct-horse-42');
    await _tap(tester, 'registerSubmit');
    expect(find.text('My Diary'), findsOneWidget);

    await _tap(tester, 'logoutButton');
    expect(find.text('Sign in'), findsWidgets);
    expect(auth.isSignedIn, isFalse);

    await tester.enterText(find.byKey(const Key('loginEmail')), 'PAT@example.com');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'correct-horse-42');
    await _tap(tester, 'loginSubmit');
    expect(find.text('My Diary'), findsOneWidget);
  });

  testWidgets('wrong password shows an error and stays on login', (tester) async {
    final repo = FakeAuthRepository();
    await repo.register(email: 'pat@example.com', password: 'correct-horse-42', displayName: 'Pat');
    await tester.pumpWidget(YvotyApp(auth: await signedOutAuth(repository: repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('loginEmail')), 'pat@example.com');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'wrong-password');
    await _tap(tester, 'loginSubmit');

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.text('My Diary'), findsNothing);
  });

  testWidgets('duplicate email on register shows the 409 message', (tester) async {
    final repo = FakeAuthRepository();
    await repo.register(email: 'pat@example.com', password: 'correct-horse-42', displayName: 'Pat');
    await tester.pumpWidget(YvotyApp(auth: await signedOutAuth(repository: repo)));
    await tester.pumpAndSettle();

    await _tap(tester, 'goToRegister');
    await tester.enterText(find.byKey(const Key('registerDisplayName')), 'Pat 2');
    await tester.enterText(find.byKey(const Key('registerEmail')), 'pat@example.com');
    await tester.enterText(find.byKey(const Key('registerPassword')), 'correct-horse-42');
    await _tap(tester, 'registerSubmit');

    expect(find.text('That email is already registered. Sign in instead.'), findsOneWidget);
  });

  testWidgets('client-side validation blocks bad input before any request', (tester) async {
    final auth = await signedOutAuth();
    await tester.pumpWidget(YvotyApp(auth: auth));
    await tester.pumpAndSettle();

    await _tap(tester, 'goToRegister');
    await tester.enterText(find.byKey(const Key('registerEmail')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('registerPassword')), 'é' * 40); // 80 bytes
    await _tap(tester, 'registerSubmit');

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('At most 72 bytes (shorter, or fewer accented characters)'), findsOneWidget);
    expect(auth.isSignedIn, isFalse);

    await tester.enterText(find.byKey(const Key('registerPassword')), 'short');
    await _tap(tester, 'registerSubmit');
    expect(find.text('At least 8 characters'), findsOneWidget);
  });

  testWidgets('server 422 shows the field message under the email field', (tester) async {
    final auth = await signedOutAuth(repository: _Rejects422());
    await tester.pumpWidget(YvotyApp(auth: auth));
    await tester.pumpAndSettle();

    await _tap(tester, 'goToRegister');
    await tester.enterText(find.byKey(const Key('registerDisplayName')), 'Ana');
    await tester.enterText(find.byKey(const Key('registerEmail')), 'ana.@example.com');
    await tester.enterText(find.byKey(const Key('registerPassword')), 'correct-horse-42');
    await _tap(tester, 'registerSubmit');

    expect(find.text('value is not a valid email address'), findsOneWidget);
    expect(find.text('Please check the fields and try again.'), findsNothing);
    expect(find.byKey(const Key('registerSubmit')), findsOneWidget);
    expect(auth.isSignedIn, isFalse);

    await tester.enterText(find.byKey(const Key('registerEmail')), 'ana@example.com');
    await tester.pump();
    expect(find.text('value is not a valid email address'), findsNothing);
  });

  test('password length counts code points, not UTF-16 units', () {
    expect(validateNewPassword('😀😀😀😀'), 'At least 8 characters');
    expect(validateNewPassword('😀' * 8), isNull);
    expect(validateDisplayName('😀' * 100), isNull);
  });
}
