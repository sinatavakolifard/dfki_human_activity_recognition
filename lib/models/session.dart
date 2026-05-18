import 'dart:convert';

class SessionMetadata {
  final String sessionId;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int sampleCount;
  final int targetHz;
  final String relativePath;
  final String? description;
  final DateTime? uploadedAt;

  const SessionMetadata({
    required this.sessionId,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.sampleCount,
    required this.targetHz,
    required this.relativePath,
    this.description,
    this.uploadedAt,
  });

  Duration get duration => endedAt.difference(startedAt);

  bool get isUploaded => uploadedAt != null;

  SessionMetadata copyWith({
    String? description,
    DateTime? uploadedAt,
  }) {
    return SessionMetadata(
      sessionId: sessionId,
      userId: userId,
      startedAt: startedAt,
      endedAt: endedAt,
      sampleCount: sampleCount,
      targetHz: targetHz,
      relativePath: relativePath,
      description: description ?? this.description,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'sampleCount': sampleCount,
        'targetHz': targetHz,
        'relativePath': relativePath,
        'description': description,
        'uploadedAt': uploadedAt?.toIso8601String(),
      };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) =>
      SessionMetadata(
        sessionId: json['sessionId'] as String,
        userId: json['userId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        sampleCount: json['sampleCount'] as int,
        targetHz: json['targetHz'] as int,
        relativePath: json['relativePath'] as String,
        description: json['description'] as String?,
        uploadedAt: json['uploadedAt'] == null
            ? null
            : DateTime.parse(json['uploadedAt'] as String),
      );

  String encode() => jsonEncode(toJson());

  static SessionMetadata decode(String raw) =>
      SessionMetadata.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
