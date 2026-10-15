import 'package:shared_preferences/shared_preferences.dart';
import 'package:yvoty/data/repositories/auth_repository.dart';
import 'package:yvoty/data/token_store.dart';
import 'package:yvoty/features/auth/auth_controller.dart';

/// An AuthController on FakeAuthRepository with mocked prefs, already signed in.
Future<AuthController> signedInAuth() async {
  final repo = FakeAuthRepository();
  final session =
      await repo.register(email: 'tester@example.com', password: 'password123', displayName: 'Tester');
  SharedPreferences.setMockInitialValues({TokenStore.key: session.accessToken});
  final auth =
      AuthController(repository: repo, tokens: TokenStore(await SharedPreferences.getInstance()));
  await auth.restore();
  return auth;
}

/// Same, with no stored token (the app should show the login screen).
Future<AuthController> signedOutAuth({FakeAuthRepository? repository}) async {
  SharedPreferences.setMockInitialValues({});
  return AuthController(
    repository: repository ?? FakeAuthRepository(),
    tokens: TokenStore(await SharedPreferences.getInstance()),
  );
}
