// models/user_data.dart
class UserData {
  final String? name;
  final String? bio;
  final String? gender;
  final DateTime? birthDate;
  final int? weight; // in kg
  final int? height; // in cm
  final String? activityLevel;
  final String? goal;
  final double? goalAdjustment; // custom calorie adjustment

  UserData({
    this.name,
    this.bio,
    this.gender,
    this.birthDate,
    this.weight,
    this.height,
    this.activityLevel,
    this.goal,
    this.goalAdjustment,
  });

  // Calculate age from birth date
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int calculatedAge = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  // Check if all required data is available for calorie calculation
  bool get isComplete {
    return gender != null &&
        birthDate != null &&
        weight != null &&
        height != null &&
        activityLevel != null &&
        goal != null;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bio': bio,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String(),
      'weight': weight,
      'height': height,
      'activityLevel': activityLevel,
      'goal': goal,
      'goalAdjustment': goalAdjustment,
    };
  }

  // Create from JSON
  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'],
      bio: json['bio'],
      gender: json['gender'],
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'])
          : null,
      weight: json['weight'],
      height: json['height'],
      activityLevel: json['activityLevel'],
      goal: json['goal'],
      goalAdjustment: json['goalAdjustment']?.toDouble(),
    );
  }

  // Create a copy with updated values
  UserData copyWith({
    String? name,
    String? bio,
    String? gender,
    DateTime? birthDate,
    int? weight,
    int? height,
    String? activityLevel,
    String? goal,
    double? goalAdjustment,
  }) {
    return UserData(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      goalAdjustment: goalAdjustment ?? this.goalAdjustment,
    );
  }

  @override
  String toString() {
    return 'UserData(gender: $gender, age: $age, weight: $weight, height: $height, activityLevel: $activityLevel, goal: $goal)';
  }
}