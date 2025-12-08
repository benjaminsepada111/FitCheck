// models/user_data.dart
class UserData {
  final String? name;
  final String? bio;
  final List<String>? hobbies; // user's selected hobbies/interests
  final String? gender;
  final DateTime? birthDate;
  final double? weight; // in kg (supports decimals)
  final int? height; // in cm
  final String? activityLevel;
  final String? goal;
  final double? goalAdjustment; // custom calorie adjustment
  final DateTime? startDate; // user's journey start date for time tracking
  final String? profilePictureUrl; // Firebase Storage URL for profile picture

  UserData({
    this.name,
    this.bio,
    this.hobbies,
    this.gender,
    this.birthDate,
    this.weight,
    this.height,
    this.activityLevel,
    this.goal,
    this.goalAdjustment,
    this.startDate,
    this.profilePictureUrl,
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

  // Check if all required data is available for user profile
  // Note: activityLevel and goal are now set per-challenge, not during onboarding
  bool get isComplete {
    return gender != null &&
        birthDate != null &&
        weight != null &&
        height != null;
  }

  // Check if all required data is available for calorie calculation (including challenge-specific data)
  bool get isCompleteForCalculation {
    return isComplete &&
        activityLevel != null &&
        goal != null;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bio': bio,
      'hobbies': hobbies,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String(),
      'weight': weight,
      'height': height,
      'activityLevel': activityLevel,
      'goal': goal,
      'goalAdjustment': goalAdjustment,
      'startDate': startDate?.toIso8601String(),
      'profilePictureUrl': profilePictureUrl,
    };
  }

  // Create from JSON
  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'],
      bio: json['bio'],
      hobbies: json['hobbies'] != null
          ? List<String>.from(json['hobbies'])
          : null,
      gender: json['gender'],
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'])
          : null,
      weight: json['weight'] != null ? (json['weight'] is int ? json['weight'].toDouble() : json['weight']?.toDouble()) : null,
      height: json['height'],
      activityLevel: json['activityLevel'],
      goal: json['goal'],
      goalAdjustment: json['goalAdjustment']?.toDouble(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      profilePictureUrl: json['profilePictureUrl'],
    );
  }

  // Create a copy with updated values
  UserData copyWith({
    String? name,
    String? bio,
    List<String>? hobbies,
    String? gender,
    DateTime? birthDate,
    double? weight,
    int? height,
    String? activityLevel,
    String? goal,
    double? goalAdjustment,
    DateTime? startDate,
    String? profilePictureUrl,
  }) {
    return UserData(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      hobbies: hobbies ?? this.hobbies,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      goalAdjustment: goalAdjustment ?? this.goalAdjustment,
      startDate: startDate ?? this.startDate,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }

  @override
  String toString() {
    return 'UserData(gender: $gender, age: $age, weight: $weight, height: $height, activityLevel: $activityLevel, goal: $goal)';
  }
}