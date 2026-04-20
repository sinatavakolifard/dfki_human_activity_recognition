import 'package:flutter/material.dart';

import 'screens/consent_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  runApp(HarApp(storage: storage));
}

class HarApp extends StatelessWidget {
  const HarApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAR App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: _Router(storage: storage),
    );
  }
}

class _Router extends StatelessWidget {
  const _Router({required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    if (!storage.consentAccepted) {
      return ConsentScreen(storage: storage);
    }
    if (storage.userProfile == null) {
      return OnboardingScreen(storage: storage, isFirstRun: true);
    }
    return HomeScreen(storage: storage);
  }
}
