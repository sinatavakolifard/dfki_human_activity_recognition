import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session.dart';
import '../services/har_api.dart';
import '../services/storage_service.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late List<SessionMetadata> _sessions;
  final Set<String> _uploading = <String>{};

  @override
  void initState() {
    super.initState();
    _sessions = widget.storage.listSessions();
  }

  Future<void> _share(SessionMetadata s) async {
    final path = await widget.storage.sessionFileFullPath(s.relativePath);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: 'HAR session ${s.sessionId}',
    );
  }

  Future<void> _upload(SessionMetadata s) async {
    final backend = widget.storage.backendConfig;
    if (!backend.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure backend URL and API key in Preferences first.',
          ),
        ),
      );
      return;
    }
    final profile = widget.storage.userProfile;
    if (profile == null) return;
    final path = await widget.storage.sessionFileFullPath(s.relativePath);
    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local CSV is missing.')),
      );
      return;
    }

    setState(() => _uploading.add(s.sessionId));
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
        sessionId: s.sessionId,
        userId: s.userId,
        startedAt: s.startedAt,
        duration: s.duration,
        sampleCount: s.sampleCount,
        targetHz: s.targetHz,
        description: s.description,
        csvFile: file,
      );
      await widget.storage
          .markSessionUploaded(s.sessionId, DateTime.now());
      if (!mounted) return;
      setState(() {
        _sessions = widget.storage.listSessions();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      api.close();
      if (mounted) setState(() => _uploading.remove(s.sessionId));
    }
  }

  Future<void> _delete(SessionMetadata s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('The CSV file will be removed from this device.'),
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
    if (ok == true) {
      await widget.storage.deleteSession(s.sessionId);
      if (!mounted) return;
      setState(() {
        _sessions = widget.storage.listSessions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: SafeArea(
        child: _sessions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No recordings yet. Tap Start on the home screen to '
                    'record your first session.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = _sessions[index];
                  final duration = s.duration;
                  final durText =
                      '${duration.inMinutes}m ${duration.inSeconds % 60}s';
                  final hasDesc =
                      s.description != null && s.description!.isNotEmpty;
                  final uploading = _uploading.contains(s.sessionId);
                  final stats =
                      '$durText · ${s.sampleCount} samples · ${s.targetHz} Hz';
                  final statusLine = uploading
                      ? 'Uploading…'
                      : s.isUploaded
                          ? 'Uploaded ${dateFmt.format(s.uploadedAt!)}'
                          : 'Not uploaded';
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        s.isUploaded
                            ? Icons.cloud_done_outlined
                            : Icons.insert_drive_file_outlined,
                        color: s.isUploaded
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        hasDesc ? s.description! : dateFmt.format(s.startedAt),
                      ),
                      subtitle: Text(
                        '${hasDesc ? '${dateFmt.format(s.startedAt)} · ' : ''}'
                        '$stats\n$statusLine',
                      ),
                      isThreeLine: true,
                      trailing: uploading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'share') _share(s);
                                if (v == 'upload') _upload(s);
                                if (v == 'delete') _delete(s);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Text('Share CSV'),
                                ),
                                PopupMenuItem(
                                  value: 'upload',
                                  child: Text(
                                    s.isUploaded
                                        ? 'Re-upload'
                                        : 'Upload to backend',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
