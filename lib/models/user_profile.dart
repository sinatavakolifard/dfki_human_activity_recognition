import 'dart:convert';

enum Sex { male, female, other, preferNotToSay }

extension SexLabel on Sex {
  String get label => switch (this) {
        Sex.male => 'Male',
        Sex.female => 'Female',
        Sex.other => 'Other',
        Sex.preferNotToSay => 'Prefer not to say',
      };
}

class UserProfile {
  final String userId;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final Sex? sex;
  final DateTime createdAt;

  const UserProfile({
    required this.userId,
    required this.createdAt,
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.sex,
  });

  UserProfile copyWith({
    int? ageYears,
    double? heightCm,
    double? weightKg,
    Sex? sex,
  }) {
    return UserProfile(
      userId: userId,
      createdAt: createdAt,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      sex: sex ?? this.sex,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'ageYears': ageYears,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'sex': sex?.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ageYears: json['ageYears'] as int?,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        sex: json['sex'] == null
            ? null
            : Sex.values.firstWhere((s) => s.name == json['sex']),
      );

  String encode() => jsonEncode(toJson());

  static UserProfile decode(String raw) =>
      UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
