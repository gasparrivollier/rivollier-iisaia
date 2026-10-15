import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/routing.dart';
import 'core/theme.dart';
import 'data/api/api_client.dart';
import 'data/photo_picker.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/identify_repository.dart';
import 'data/repositories/plants_repository.dart';
import 'data/repositories/region_repository.dart';
import 'data/token_store.dart';
import 'features/auth/auth_controller.dart';

/// True only in builds made with `--dart-define=E2E=true` (Playwright runs).
/// Forces Flutter Web to emit its DOM semantics tree so tests can locate widgets.
const bool kE2E = bool.fromEnvironment('E2E');

/// Backend base URL (`--dart-define=API_BASE_URL=...`). Its pairing with the web
/// origin must be listed in the backend's CORS_ORIGINS.
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kE2E) {
    SemanticsBinding.instance.ensureSemantics();
  }
  // The hook needs the controller, which needs the repository, which needs the client.
  late final AuthController auth;
  final api = ApiClient(baseUrl: kApiBaseUrl, onUnauthorized: () => auth.logout());
  auth = AuthController(
    repository: HttpAuthRepository(api),
    tokens: TokenStore(await SharedPreferences.getInstance()),
  );
  // Before runApp, so a reload with a valid token never flashes the login screen.
  await auth.restore();
  runApp(YvotyApp(auth: auth, api: api));
}

class YvotyApp extends StatefulWidget {
  const YvotyApp({super.key, required this.auth, this.api, this.photoPicker});

  final AuthController auth;
  final ApiClient? api;
  final PhotoPicker? photoPicker;

  @override
  State<YvotyApp> createState() => _YvotyAppState();
}

class _YvotyAppState extends State<YvotyApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: widget.auth),
        Provider<IdentifyRepository>(
          create: (_) => widget.api == null
              ? FakeIdentifyRepository()
              : HttpIdentifyRepository(widget.api!, readToken: () => widget.auth.token),
        ),
        Provider<PhotoPicker>(create: (_) => widget.photoPicker ?? FilePickerPhotoPicker()),
        Provider<PlantsRepository>(create: (_) => FakePlantsRepository()),
        Provider<RegionRepository>(create: (_) => FakeRegionRepository()),
      ],
      child: MaterialApp.router(
        title: 'Yvoty',
        debugShowCheckedModeBanner: false,
        theme: buildYvotyTheme(),
        routerConfig: _router,
      ),
    );
  }
}
