import 'package:flutter/material.dart';

import '../services/har_api.dart';
import '../services/storage_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late AppPreferences _prefs;
  late BackendConfig _backend;
  late final TextEditingController _baseUrlCtl;
  late final TextEditingController _apiKeyCtl;
  bool _testingConnection = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _prefs = widget.storage.preferences;
    _backend = widget.storage.backendConfig;
    _baseUrlCtl = TextEditingController(text: _backend.baseUrl);
    _apiKeyCtl = TextEditingController(text: _backend.apiKey);
  }

  @override
  void dispose() {
    _baseUrlCtl.dispose();
    _apiKeyCtl.dispose();
    super.dispose();
  }

  Future<void> _updateMaxMinutes(int minutes) async {
    final updated = _prefs.copyWith(maxRecordingMinutes: minutes);
    await widget.storage.savePreferences(updated);
    if (!mounted) return;
    setState(() => _prefs = updated);
  }

  Future<void> _saveBackend({bool? uploadOptIn}) async {
    final updated = _backend.copyWith(
      baseUrl: _baseUrlCtl.text.trim(),
      apiKey: _apiKeyCtl.text.trim(),
      uploadOptIn: uploadOptIn,
    );
    await widget.storage.saveBackendConfig(updated);
    if (!mounted) return;
    setState(() => _backend = updated);
  }

  Future<void> _toggleUploadOptIn(bool value) async {
    if (value && !_backend.copyWith(
      baseUrl: _baseUrlCtl.text.trim(),
      apiKey: _apiKeyCtl.text.trim(),
    ).isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a base URL and API key before enabling uploads.'),
        ),
      );
      return;
    }
    await _saveBackend(uploadOptIn: value);
  }

  Future<void> _testConnection() async {
    final baseUrl = _baseUrlCtl.text.trim();
    final apiKey = _apiKeyCtl.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter base URL and API key first.')),
      );
      return;
    }
    setState(() => _testingConnection = true);
    final api = HarApi(baseUrl: baseUrl, apiKey: apiKey);
    try {
      final ok = await api.health();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Connected to backend.'
              : 'Backend did not respond ok. Check the URL.'),
        ),
      );
      if (ok) await _saveBackend();
    } finally {
      api.close();
      if (mounted) setState(() => _testingConnection = false);
    }
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
            Text('Backend uploads', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Optionally send completed recordings to a research server. '
              'Uploads only happen when you turn the switch on; data otherwise '
              'stays on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlCtl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Server base URL',
                hintText: 'https://har.example.org',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveBackend(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyCtl,
              obscureText: _obscureApiKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureApiKey ? 'Show' : 'Hide',
                  icon: Icon(_obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              onChanged: (_) => _saveBackend(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    onPressed: _testingConnection ? null : _testConnection,
                    label: const Text('Test connection'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Upload recordings'),
              subtitle: Text(
                _backend.uploadOptIn
                    ? 'New sessions are sent to the server after they finish.'
                    : 'Recordings stay on this device.',
              ),
              value: _backend.uploadOptIn,
              onChanged: _toggleUploadOptIn,
            ),
            const SizedBox(height: 32),
            Text('Privacy', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'HAR App only records IMU data (accelerometer, gyroscope, '
              'magnetometer) while a session is active. Recordings stay on '
              'this device unless you opt in to backend uploads above.',
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
