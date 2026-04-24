import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import 'onboarding_screen.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.storage});

  final StorageService storage;

  Future<void> _accept(BuildContext context) async {
    await storage.setConsentAccepted(true);
    await storage.ensureUserProfile();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(storage: storage, isFirstRun: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.sensors,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to HAR App',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Human Activity Recognition research',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Section(
                        icon: Icons.check_circle_outline,
                        title: 'What we collect',
                        body:
                            'Only IMU sensor data: accelerometer, gyroscope, '
                            'and magnetometer, sampled at 34 Hz while you '
                            'are recording.',
                      ),
                      _Section(
                        icon: Icons.block,
                        title: 'What we never collect',
                        body:
                            'No location, no microphone, no camera, no '
                            'contacts, no identifiers tied to your account or '
                            'device, no advertising data.',
                      ),
                      _Section(
                        icon: Icons.person_outline,
                        title: 'Your identity',
                        body:
                            'We generate a random anonymous ID for this '
                            'install. You are never asked to log in. You may '
                            'optionally share age, height, weight and gender to '
                            'help the research.',
                      ),
                      _Section(
                        icon: Icons.storage,
                        title: 'Where the data is stored',
                        body:
                            'Recordings are saved on this device. A future '
                            'version may offer to upload them to a research '
                            'database; that will be opt-in.',
                      ),
                      _Section(
                        icon: Icons.play_circle_outline,
                        title: 'You are in control',
                        body:
                            'Recording only happens while you hold a session '
                            'open. Tap Stop any time to end it. Delete any '
                            'recording from the Sessions list.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _accept(context),
                child: const Text('I agree, continue'),
              ),
              const SizedBox(height: 8),
              Text(
                'By continuing you confirm you are 18+ and agree to the '
                'above data handling.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
