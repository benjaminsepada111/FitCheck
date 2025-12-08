// models/weekly_checkin.dart
class WeeklyCheckIn {
  final String id;
  final String challengeId;
  final DateTime checkInDate;
  final int weekNumber; // Week 1, Week 2, etc.
  final double currentWeight; // in kg (supports decimals)
  final double? previousWeight; // Weight from last check-in (in kg, supports decimals)
  final double? weightChange; // Calculated weight change (kg)
  final String? weightTrend; // 'up', 'down', or 'same' - automatically determined
  final String? notes;
  final String? progressFeeling; // 'great', 'good', 'okay', 'struggling'
  final String? activityLevelChange; // 'increased', 'decreased', 'no_change'
  final int? previousCalorieGoal;
  final int? newCalorieGoal;
  final int? calorieAdjustment; // Applied adjustment (+/- calories)
  final String? progressInterpretation; // 'maintained', 'slight_deficit', 'surplus', etc.
  final String? adaptiveReason; // Why the adjustment was made
  final bool? goalAdjusted; // Whether the calorie goal was actually adjusted
  final String? adjustmentNotice; // Notice message if adjustment was not made
  final int? weeklyCaloriesConsumed; // Total calories consumed in that week
  final int? weeklyCaloriesBurned; // Total calories burned in that week
  final DateTime createdAt;

  WeeklyCheckIn({
    required this.id,
    required this.challengeId,
    required this.checkInDate,
    required this.weekNumber,
    required this.currentWeight,
    this.previousWeight,
    this.weightChange,
    this.weightTrend,
    this.notes,
    this.progressFeeling,
    this.activityLevelChange,
    this.previousCalorieGoal,
    this.newCalorieGoal,
    this.calorieAdjustment,
    this.progressInterpretation,
    this.adaptiveReason,
    this.goalAdjusted,
    this.adjustmentNotice,
    this.weeklyCaloriesConsumed,
    this.weeklyCaloriesBurned,
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
      'weightTrend': weightTrend,
      'notes': notes,
      'progressFeeling': progressFeeling,
      'activityLevelChange': activityLevelChange,
      'previousCalorieGoal': previousCalorieGoal,
      'newCalorieGoal': newCalorieGoal,
      'calorieAdjustment': calorieAdjustment,
      'progressInterpretation': progressInterpretation,
      'adaptiveReason': adaptiveReason,
      'goalAdjusted': goalAdjusted,
      'adjustmentNotice': adjustmentNotice,
      'weeklyCaloriesConsumed': weeklyCaloriesConsumed,
      'weeklyCaloriesBurned': weeklyCaloriesBurned,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WeeklyCheckIn.fromJson(Map<String, dynamic> json) {
    return WeeklyCheckIn(
      id: json['id'],
      challengeId: json['challengeId'],
      checkInDate: DateTime.parse(json['checkInDate']),
      weekNumber: json['weekNumber'],
      currentWeight: (json['currentWeight'] is int ? json['currentWeight'].toDouble() : json['currentWeight']).toDouble(),
      previousWeight: json['previousWeight'] != null ? (json['previousWeight'] is int ? json['previousWeight'].toDouble() : json['previousWeight']).toDouble() : null,
      weightChange: json['weightChange']?.toDouble(),
      weightTrend: json['weightTrend'],
      notes: json['notes'],
      progressFeeling: json['progressFeeling'],
      activityLevelChange: json['activityLevelChange'],
      previousCalorieGoal: json['previousCalorieGoal'],
      newCalorieGoal: json['newCalorieGoal'],
      calorieAdjustment: json['calorieAdjustment'],
      progressInterpretation: json['progressInterpretation'],
      adaptiveReason: json['adaptiveReason'],
      goalAdjusted: json['goalAdjusted'],
      adjustmentNotice: json['adjustmentNotice'],
      weeklyCaloriesConsumed: json['weeklyCaloriesConsumed'],
      weeklyCaloriesBurned: json['weeklyCaloriesBurned'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  WeeklyCheckIn copyWith({
    String? id,
    String? challengeId,
    DateTime? checkInDate,
    int? weekNumber,
    double? currentWeight,
    double? previousWeight,
    double? weightChange,
    String? weightTrend,
    String? notes,
    String? progressFeeling,
    String? activityLevelChange,
    int? previousCalorieGoal,
    int? newCalorieGoal,
    int? calorieAdjustment,
    String? progressInterpretation,
    String? adaptiveReason,
    bool? goalAdjusted,
    String? adjustmentNotice,
    int? weeklyCaloriesConsumed,
    int? weeklyCaloriesBurned,
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
      weightTrend: weightTrend ?? this.weightTrend,
      notes: notes ?? this.notes,
      progressFeeling: progressFeeling ?? this.progressFeeling,
      activityLevelChange: activityLevelChange ?? this.activityLevelChange,
      previousCalorieGoal: previousCalorieGoal ?? this.previousCalorieGoal,
      newCalorieGoal: newCalorieGoal ?? this.newCalorieGoal,
      calorieAdjustment: calorieAdjustment ?? this.calorieAdjustment,
      progressInterpretation: progressInterpretation ?? this.progressInterpretation,
      adaptiveReason: adaptiveReason ?? this.adaptiveReason,
      goalAdjusted: goalAdjusted ?? this.goalAdjusted,
      adjustmentNotice: adjustmentNotice ?? this.adjustmentNotice,
      weeklyCaloriesConsumed: weeklyCaloriesConsumed ?? this.weeklyCaloriesConsumed,
      weeklyCaloriesBurned: weeklyCaloriesBurned ?? this.weeklyCaloriesBurned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
