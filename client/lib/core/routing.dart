import 'package:go_router/go_router.dart';

import '../data/models/identification_result.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/garden/diary_screen.dart';
import '../features/identify/capture_screen.dart';
import '../features/identify/results_screen.dart';
import '../features/plants/plant_detail_screen.dart';
import '../features/region/region_map_screen.dart';

const _authPaths = {'/login', '/register'};

/// Signed-out users only see /login and /register; signed-in users skip them.
GoRouter buildRouter(AuthController auth) => GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        final onAuthPage = _authPaths.contains(state.matchedLocation);
        if (!auth.isSignedIn) return onAuthPage ? null : '/login';
        return onAuthPage ? '/' : null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/', builder: (context, state) => const DiaryScreen()),
        GoRoute(path: '/capture', builder: (context, state) => const CaptureScreen()),
        GoRoute(
          path: '/results',
          builder: (context, state) {
            final candidates = state.extra as List<IdentificationResult>;
            return ResultsScreen(candidates: candidates);
          },
        ),
        GoRoute(
          path: '/plants/:id',
          builder: (context, state) => PlantDetailScreen(plantId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/region', builder: (context, state) => const RegionMapScreen()),
      ],
    );
