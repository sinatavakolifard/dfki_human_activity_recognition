import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/sensor_sample.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../services/har_api.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import 'onboarding_screen.dart';
import 'preferences_screen.dart';
import 'sessions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _targetHz = 34;

  final SensorService _service = SensorService(targetHz: _targetHz);
  final TextEditingController _descriptionCtl = TextEditingController();
  StreamSubscription<SensorSample>? _sub;
  SessionWriter? _writer;
  Timer? _elapsedTimer;
  Timer? _autoStopTimer;

  DateTime? _startedAt;
  int _samplesWritten = 0;
  SensorSample? _latestSample;
  String? _currentSessionId;
  bool _isRecording = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _elapsedTimer?.cancel();
    _autoStopTimer?.cancel();
    _writer?.close();
    _service.dispose();
    _descriptionCtl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_isRecording) {
      await _stop(reason: 'user');
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final profile = await widget.storage.ensureUserProfile();
      final prefs = widget.storage.preferences;
      final sessionId = const Uuid().v4();
      final file = await widget.storage.createSessionFile(sessionId);
      final writer = SessionWriter(file);
      await writer.open();

      _writer = writer;
      _currentSessionId = sessionId;
      _startedAt = DateTime.now();
      _samplesWritten = 0;
      _latestSample = null;

      _sub = _service.samples.listen((s) {
        _writer?.add(s);
        _samplesWritten++;
        _latestSample = s;
      });
      await _service.start();

      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      _autoStopTimer = Timer(
        Duration(minutes: prefs.maxRecordingMinutes),
        () => _stop(reason: 'auto'),
      );

      // Reference profile to avoid unused variable warnings in release.
      assert(profile.userId.isNotEmpty);

      setState(() => _isRecording = true);
    } catch (e) {
      await _cleanupFailedStart();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanupFailedStart() async {
    await _sub?.cancel();
    _sub = null;
    _elapsedTimer?.cancel();
    _autoStopTimer?.cancel();
    await _writer?.close();
    _writer = null;
    await _service.stop();
    _isRecording = false;
  }

  Future<void> _stop({required String reason}) async {
    if (!_isRecording || _busy) return;
    setState(() => _busy = true);
    final startedAt = _startedAt!;
    final writer = _writer;
    final sessionId = _currentSessionId!;
    final endedAt = DateTime.now();

    try {
      await _service.stop();
      await _sub?.cancel();
      _sub = null;
      _elapsedTimer?.cancel();
      _autoStopTimer?.cancel();
      await writer?.close();

      String description = _descriptionCtl.text.trim();
      if (description.isEmpty && mounted) {
        final fromDialog = await _promptForDescription();
        description = (fromDialog ?? '').trim();
      }

      final profile = await widget.storage.ensureUserProfile();
      final relative = 'sessions/$sessionId.csv';
      final metadata = SessionMetadata(
        sessionId: sessionId,
        userId: profile.userId,
        startedAt: startedAt,
        endedAt: endedAt,
        sampleCount: _samplesWritten,
        targetHz: _targetHz,
        relativePath: relative,
        description: description.isEmpty ? null : description,
      );
      await widget.storage.addSession(metadata);
      _descriptionCtl.clear();

      if (!mounted) return;
      final seconds = endedAt.difference(startedAt).inSeconds;
      final msg = reason == 'auto'
          ? 'Max recording time reached. Saved $_samplesWritten samples '
                '(${seconds}s).'
          : 'Saved $_samplesWritten samples (${seconds}s).';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      unawaited(_maybeUploadSession(metadata, profile));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping: $e')));
      }
    } finally {
      _writer = null;
      _currentSessionId = null;
      if (mounted) {
        setState(() {
          _isRecording = false;
          _busy = false;
        });
      }
    }
  }

  Future<String?> _promptForDescription() {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _LabelPromptDialog(),
    );
  }

  Future<void> _maybeUploadSession(
    SessionMetadata metadata,
    UserProfile profile,
  ) async {
    final backend = widget.storage.backendConfig;
    if (!backend.isReadyForUpload) return;
    final path =
        await widget.storage.sessionFileFullPath(metadata.relativePath);
    final file = File(path);
    if (!await file.exists()) return;

    final api = HarApi(baseUrl: backend.baseUrl, apiKey: backend.apiKey);
    try {
      await api.upsertUser(
        userId: profile.userId,
        ageYears: profile.ageYears,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        gender: profile.gender,
      );
      await api.uploadSession(
        sessionId: metadata.sessionId,
        userId: metadata.userId,
        startedAt: metadata.startedAt,
        duration: metadata.duration,
        sampleCount: metadata.sampleCount,
        targetHz: metadata.targetHz,
        description: metadata.description,
        csvFile: file,
      );
      await widget.storage
          .markSessionUploaded(metadata.sessionId, DateTime.now());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording uploaded to backend.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e. Retry from Sessions later.'),
        ),
      );
    } finally {
      api.close();
    }
  }

  String _formatElapsed() {
    if (_startedAt == null) return '00:00';
    final d = DateTime.now().difference(_startedAt!);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = widget.storage.preferences;
    final profile = widget.storage.userProfile;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('HAR Recorder'),
        actions: [
          IconButton(
            tooltip: 'Sessions',
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionsScreen(storage: widget.storage),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: _isRecording
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            OnboardingScreen(storage: widget.storage),
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(Icons.tune),
            onPressed: _isRecording
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PreferencesScreen(storage: widget.storage),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        _StatusBanner(
                          isRecording: _isRecording,
                          elapsed: _formatElapsed(),
                          samples: _samplesWritten,
                          targetHz: _targetHz,
                        ),
                        const SizedBox(height: 24),
                        _LiveReadout(sample: _latestSample),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descriptionCtl,
                          minLines: 1,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'What are you doing? (optional)',
                            hintText: 'e.g. walking upstairs',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _BigButton(
                          isRecording: _isRecording,
                          busy: _busy,
                          onTap: _toggle,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile == null
                              ? 'No profile yet'
                              : 'User ${profile.userId.substring(0, 8)} · '
                                    'max ${prefs.maxRecordingMinutes} min',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelPromptDialog extends StatefulWidget {
  const _LabelPromptDialog();

  @override
  State<_LabelPromptDialog> createState() => _LabelPromptDialogState();
}

class _LabelPromptDialogState extends State<_LabelPromptDialog> {
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Label this recording?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A short note about what you were doing helps researchers '
            'interpret the data. Optional but recommended.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctl,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. walking upstairs',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.isRecording,
    required this.elapsed,
    required this.samples,
    required this.targetHz,
  });

  final bool isRecording;
  final String elapsed;
  final int samples;
  final int targetHz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isRecording
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final onColor = isRecording
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isRecording
                ? Icons.fiber_manual_record
                : Icons.pause_circle_outline,
            color: onColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRecording ? 'Recording' : 'Idle',
                  style: theme.textTheme.titleMedium?.copyWith(color: onColor),
                ),
                Text(
                  isRecording
                      ? '$elapsed · $samples samples · target ${targetHz}Hz'
                      : 'Tap Start to record IMU at ${targetHz}Hz',
                  style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveReadout extends StatelessWidget {
  const _LiveReadout({required this.sample});

  final SensorSample? sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sample;
    final fmt = NumberFormat('0.00', 'en_US');
    Widget row(String label, double x, double y, double z, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            Expanded(
              child: Text(
                'x ${fmt.format(x)}   y ${fmt.format(y)}   z ${fmt.format(z)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live sensors', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (s == null)
            Text(
              'Values will appear here while recording.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            row('accel', s.accelX, s.accelY, s.accelZ, Icons.speed_outlined),
            row('gyro', s.gyroX, s.gyroY, s.gyroZ, Icons.rotate_right_outlined),
            row('mag', s.magX, s.magY, s.magZ, Icons.explore_outlined),
          ],
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.isRecording,
    required this.busy,
    required this.onTap,
  });

  final bool isRecording;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  isRecording ? 'Stop' : 'Start',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}
