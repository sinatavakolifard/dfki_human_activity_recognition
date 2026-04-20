import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session.dart';
import '../services/storage_service.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late List<SessionMetadata> _sessions;

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
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(dateFmt.format(s.startedAt)),
                      subtitle: Text(
                        '$durText · ${s.sampleCount} samples · '
                        '${s.targetHz} Hz',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'share') _share(s);
                          if (v == 'delete') _delete(s);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'share',
                            child: Text('Share CSV'),
                          ),
                          PopupMenuItem(
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
