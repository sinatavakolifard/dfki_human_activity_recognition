import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/session.dart';
import '../models/user_profile.dart';

class AppPreferences {
  final int maxRecordingMinutes;

  const AppPreferences({
    this.maxRecordingMinutes = 30,
  });

  AppPreferences copyWith({int? maxRecordingMinutes}) {
    return AppPreferences(
      maxRecordingMinutes: maxRecordingMinutes ?? this.maxRecordingMinutes,
    );
  }
}

class BackendConfig {
  final String baseUrl;
  final String apiKey;
  final bool uploadOptIn;

  const BackendConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.uploadOptIn = false,
  });

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  bool get isReadyForUpload => isConfigured && uploadOptIn;

  BackendConfig copyWith({
    String? baseUrl,
    String? apiKey,
    bool? uploadOptIn,
  }) {
    return BackendConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      uploadOptIn: uploadOptIn ?? this.uploadOptIn,
    );
  }
}

class StorageService {
  static const _kConsentAccepted = 'consent_accepted_v1';
  static const _kUserProfile = 'user_profile_v1';
  static const _kMaxRecordingMinutes = 'max_recording_minutes';
  static const _kSessionsIndex = 'sessions_index_v1';
  static const _kBackendBaseUrl = 'backend_base_url';
  static const _kBackendApiKey = 'backend_api_key';
  static const _kBackendUploadOptIn = 'backend_upload_opt_in';

  static const List<int> recordingDurationChoicesMinutes = [5, 15, 30, 60, 120];

  final SharedPreferences _prefs;

  StorageService._(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  bool get consentAccepted => _prefs.getBool(_kConsentAccepted) ?? false;

  Future<void> setConsentAccepted(bool value) =>
      _prefs.setBool(_kConsentAccepted, value);

  UserProfile? get userProfile {
    final raw = _prefs.getString(_kUserProfile);
    if (raw == null) return null;
    try {
      return UserProfile.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> ensureUserProfile() async {
    final existing = userProfile;
    if (existing != null) return existing;
    final profile = UserProfile(
      userId: const Uuid().v4(),
      createdAt: DateTime.now(),
    );
    await saveUserProfile(profile);
    return profile;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _prefs.setString(_kUserProfile, profile.encode());
  }

  AppPreferences get preferences => AppPreferences(
        maxRecordingMinutes: _prefs.getInt(_kMaxRecordingMinutes) ?? 30,
      );

  Future<void> savePreferences(AppPreferences p) async {
    await _prefs.setInt(_kMaxRecordingMinutes, p.maxRecordingMinutes);
  }

  BackendConfig get backendConfig => BackendConfig(
        baseUrl: _prefs.getString(_kBackendBaseUrl) ?? '',
        apiKey: _prefs.getString(_kBackendApiKey) ?? '',
        uploadOptIn: _prefs.getBool(_kBackendUploadOptIn) ?? false,
      );

  Future<void> saveBackendConfig(BackendConfig config) async {
    await _prefs.setString(_kBackendBaseUrl, config.baseUrl);
    await _prefs.setString(_kBackendApiKey, config.apiKey);
    await _prefs.setBool(_kBackendUploadOptIn, config.uploadOptIn);
  }

  Future<Directory> _sessionsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/sessions');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> createSessionFile(String sessionId) async {
    final dir = await _sessionsDir();
    return File('${dir.path}/$sessionId.csv');
  }

  Future<String> sessionFileFullPath(String relativePath) async {
    final root = await getApplicationDocumentsDirectory();
    return '${root.path}/$relativePath';
  }

  List<SessionMetadata> listSessions() {
    final raw = _prefs.getStringList(_kSessionsIndex) ?? const [];
    final sessions = <SessionMetadata>[];
    for (final entry in raw) {
      try {
        sessions.add(SessionMetadata.decode(entry));
      } catch (_) {
        // skip corrupted entry
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> addSession(SessionMetadata session) async {
    final current = _prefs.getStringList(_kSessionsIndex) ?? <String>[];
    current.add(session.encode());
    await _prefs.setStringList(_kSessionsIndex, current);
  }

  Future<void> markSessionUploaded(String sessionId, DateTime when) async {
    final current = _prefs.getStringList(_kSessionsIndex) ?? <String>[];
    final updated = <String>[];
    for (final entry in current) {
      try {
        final s = SessionMetadata.decode(entry);
        if (s.sessionId == sessionId) {
          updated.add(s.copyWith(uploadedAt: when).encode());
        } else {
          updated.add(entry);
        }
      } catch (_) {
        updated.add(entry);
      }
    }
    await _prefs.setStringList(_kSessionsIndex, updated);
  }

  Future<void> deleteSession(String sessionId) async {
    final current = _prefs.getStringList(_kSessionsIndex) ?? <String>[];
    final remaining = <String>[];
    SessionMetadata? removed;
    for (final entry in current) {
      try {
        final s = SessionMetadata.decode(entry);
        if (s.sessionId == sessionId) {
          removed = s;
          continue;
        }
        remaining.add(entry);
      } catch (_) {
        remaining.add(entry);
      }
    }
    await _prefs.setStringList(_kSessionsIndex, remaining);
    if (removed != null) {
      final path = await sessionFileFullPath(removed.relativePath);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> wipeAll() async {
    final sessions = listSessions();
    for (final s in sessions) {
      final path = await sessionFileFullPath(s.relativePath);
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    await _prefs.clear();
  }
}

// Exposed for tests/tools in the future.
String encodeSessionList(List<SessionMetadata> list) =>
    jsonEncode(list.map((e) => e.toJson()).toList());
