// models/weekly_checkin.dart
class WeeklyCheckIn {
  final String id;
  final String challengeId;
  final DateTime checkInDate;
  final int weekNumber; // Week 1, Week 2, etc.
  final int currentWeight; // in kg
  final int? previousWeight; // Weight from last check-in (in kg)
  final double? weightChange; // Calculated weight change (kg)
  final String? notes;
  final String? progressFeeling; // 'great', 'good', 'okay', 'struggling'
  final String? activityLevelChange; // 'increased', 'decreased', 'no_change'
  final int? previousCalorieGoal;
  final int? newCalorieGoal;
  final int? calorieAdjustment; // Applied adjustment (+/- calories)
  final String? progressInterpretation; // 'maintained', 'slight_deficit', 'surplus', etc.
  final String? adaptiveReason; // Why the adjustment was made
  final DateTime createdAt;

  WeeklyCheckIn({
    required this.id,
    required this.challengeId,
    required this.checkInDate,
    required this.weekNumber,
    required this.currentWeight,
    this.previousWeight,
    this.weightChange,
    this.notes,
    this.progressFeeling,
    this.activityLevelChange,
    this.previousCalorieGoal,
    this.newCalorieGoal,
    this.calorieAdjustment,
    this.progressInterpretation,
    this.adaptiveReason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challengeId': challengeId,
      'checkInDate': checkInDate.toIso8601String(),
      'weekNumber': weekNumber,
      'currentWeight': currentWeight,
      'previousWeight': previousWeight,
      'weightChange': weightChange,
      'notes': notes,
      'progressFeeling': progressFeeling,
      'activityLevelChange': activityLevelChange,
      'previousCalorieGoal': previousCalorieGoal,
      'newCalorieGoal': newCalorieGoal,
      'calorieAdjustment': calorieAdjustment,
      'progressInterpretation': progressInterpretation,
      'adaptiveReason': adaptiveReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WeeklyCheckIn.fromJson(Map<String, dynamic> json) {
    return WeeklyCheckIn(
      id: json['id'],
      challengeId: json['challengeId'],
      checkInDate: DateTime.parse(json['checkInDate']),
      weekNumber: json['weekNumber'],
      currentWeight: json['currentWeight'],
      previousWeight: json['previousWeight'],
      weightChange: json['weightChange']?.toDouble(),
      notes: json['notes'],
      progressFeeling: json['progressFeeling'],
      activityLevelChange: json['activityLevelChange'],
      previousCalorieGoal: json['previousCalorieGoal'],
      newCalorieGoal: json['newCalorieGoal'],
      calorieAdjustment: json['calorieAdjustment'],
      progressInterpretation: json['progressInterpretation'],
      adaptiveReason: json['adaptiveReason'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  WeeklyCheckIn copyWith({
    String? id,
    String? challengeId,
    DateTime? checkInDate,
    int? weekNumber,
    int? currentWeight,
    int? previousWeight,
    double? weightChange,
    String? notes,
    String? progressFeeling,
    String? activityLevelChange,
    int? previousCalorieGoal,
    int? newCalorieGoal,
    int? calorieAdjustment,
    String? progressInterpretation,
    String? adaptiveReason,
    DateTime? createdAt,
  }) {
    return WeeklyCheckIn(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      checkInDate: checkInDate ?? this.checkInDate,
      weekNumber: weekNumber ?? this.weekNumber,
      currentWeight: currentWeight ?? this.currentWeight,
      previousWeight: previousWeight ?? this.previousWeight,
      weightChange: weightChange ?? this.weightChange,
      notes: notes ?? this.notes,
      progressFeeling: progressFeeling ?? this.progressFeeling,
      activityLevelChange: activityLevelChange ?? this.activityLevelChange,
      previousCalorieGoal: previousCalorieGoal ?? this.previousCalorieGoal,
      newCalorieGoal: newCalorieGoal ?? this.newCalorieGoal,
      calorieAdjustment: calorieAdjustment ?? this.calorieAdjustment,
      progressInterpretation: progressInterpretation ?? this.progressInterpretation,
      adaptiveReason: adaptiveReason ?? this.adaptiveReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
