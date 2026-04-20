import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late AppPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.storage.preferences;
  }

  Future<void> _updateMaxMinutes(int minutes) async {
    final updated = _prefs.copyWith(maxRecordingMinutes: minutes);
    await widget.storage.savePreferences(updated);
    if (!mounted) return;
    setState(() => _prefs = updated);
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This removes every saved recording and resets your profile. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storage.wipeAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Recording', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Maximum recording time per session. The app will stop '
              'automatically when this time is reached.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in StorageService.recordingDurationChoicesMinutes)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _prefs.maxRecordingMinutes == m,
                    onSelected: (_) => _updateMaxMinutes(m),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Privacy', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'HAR App only records IMU data (accelerometer, gyroscope, '
              'magnetometer) while a session is active. Data stays on this '
              'device and is never uploaded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _confirmDeleteAll,
              label: const Text('Delete all recordings and profile'),
            ),
          ],
        ),
      ),
    );
  }
}
