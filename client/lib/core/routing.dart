import 'package:go_router/go_router.dart';

import '../data/models/identification_result.dart';
import '../features/garden/diary_screen.dart';
import '../features/identify/capture_screen.dart';
import '../features/identify/results_screen.dart';
import '../features/plants/plant_detail_screen.dart';
import '../features/region/region_map_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
