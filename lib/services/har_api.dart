import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';

class HarApiException implements Exception {
  HarApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HarApiException($statusCode): $message';
}

class HarApi {
  HarApi({required String baseUrl, required this.apiKey, http.Client? client})
      : baseUrl = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri baseUrl;
  final String apiKey;
  final http.Client _client;

  static const Duration _defaultTimeout = Duration(seconds: 30);

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  Future<bool> health() async {
    try {
      final r = await _client
          .get(baseUrl.resolve('/health'))
          .timeout(_defaultTimeout);
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<void> upsertUser({
    required String userId,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    Gender? gender,
  }) async {
    final r = await _client
        .put(
          baseUrl.resolve('/v1/users/$userId'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'age': ?ageYears,
            'height_cm': ?heightCm?.round(),
            'weight_kg': ?weightKg?.round(),
            'gender': ?(gender == null ? null : _genderApiValue(gender)),
          }),
        )
        .timeout(_defaultTimeout);
    if (r.statusCode >= 300) {
      throw HarApiException(r.statusCode, 'upsertUser failed: ${r.body}');
    }
  }

  Future<void> uploadSession({
    required String sessionId,
    required String userId,
    required DateTime startedAt,
    required Duration duration,
    required int sampleCount,
    required int targetHz,
    String? description,
    required File csvFile,
  }) async {
    final csvBytes = await csvFile.readAsBytes();
    final gz = Uint8List.fromList(gzip.encode(csvBytes));
    final sha = sha256.convert(csvBytes).toString();

    final req = http.MultipartRequest('POST', baseUrl.resolve('/v1/sessions'))
      ..headers['X-API-Key'] = apiKey
      ..fields['metadata'] = jsonEncode({
        'id': sessionId,
        'user_id': userId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_ms': duration.inMilliseconds,
        'sample_count': sampleCount,
        'target_hz': targetHz,
        if (description != null && description.isNotEmpty)
          'description': description,
        'csv_uncompressed_bytes': csvBytes.length,
        'csv_sha256': sha,
      })
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        gz,
        filename: '$sessionId.csv.gz',
      ));

    final streamed = await req.send().timeout(const Duration(minutes: 5));
    if (streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw HarApiException(
        streamed.statusCode,
        'uploadSession failed: $body',
      );
    }
    // Drain the response body so the connection can be reused.
    await streamed.stream.drain<void>();
  }

  Future<void> deleteSession(String sessionId) async {
    final r = await _client
        .delete(
          baseUrl.resolve('/v1/sessions/$sessionId'),
          headers: {'X-API-Key': apiKey},
        )
        .timeout(_defaultTimeout);
    if (r.statusCode >= 300 && r.statusCode != 404) {
      throw HarApiException(r.statusCode, 'deleteSession failed: ${r.body}');
    }
  }

  void close() => _client.close();

  // The backend stores gender as a free-form short string. Map our enum to a
  // stable serialization so re-uploading the same profile is a no-op.
  static String _genderApiValue(Gender g) => switch (g) {
        Gender.male => 'male',
        Gender.female => 'female',
        Gender.other => 'other',
        Gender.preferNotToSay => 'prefer_not_to_say',
      };
}
