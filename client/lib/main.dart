import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing.dart';
import 'core/theme.dart';
import 'data/repositories/identify_repository.dart';
import 'data/repositories/plants_repository.dart';
import 'data/repositories/region_repository.dart';

void main() {
  runApp(const YvotyApp());
}

class YvotyApp extends StatelessWidget {
  const YvotyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<IdentifyRepository>(create: (_) => FakeIdentifyRepository()),
        Provider<PlantsRepository>(create: (_) => FakePlantsRepository()),
        Provider<RegionRepository>(create: (_) => FakeRegionRepository()),
      ],
      child: MaterialApp.router(
        title: 'Yvoty',
        debugShowCheckedModeBanner: false,
        theme: buildYvotyTheme(),
        routerConfig: appRouter,
      ),
    );
  }
}
