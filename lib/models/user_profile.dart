import 'dart:convert';

enum Gender { male, female, other, preferNotToSay }

extension GenderLabel on Gender {
  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };
}

class UserProfile {
  final String userId;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final Gender? gender;
  final DateTime createdAt;

  const UserProfile({
    required this.userId,
    required this.createdAt,
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.gender,
  });

  UserProfile copyWith({
    int? ageYears,
    double? heightCm,
    double? weightKg,
    Gender? gender,
  }) {
    return UserProfile(
      userId: userId,
      createdAt: createdAt,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'ageYears': ageYears,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'gender': gender?.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ageYears: json['ageYears'] as int?,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        gender: json['gender'] == null
            ? null
            : Gender.values.firstWhere((g) => g.name == json['gender']),
      );

  String encode() => jsonEncode(toJson());

  static UserProfile decode(String raw) =>
      UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
