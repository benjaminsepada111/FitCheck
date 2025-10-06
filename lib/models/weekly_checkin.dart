// models/weekly_checkin.dart
class WeeklyCheckIn {
  final String id;
  final String challengeId;
  final DateTime checkInDate;
  final int weekNumber; // Week 1, Week 2, etc.
  final int currentWeight; // in kg
  final String? notes;
  final String? progressFeeling; // 'great', 'good', 'okay', 'struggling'
  final int? previousCalorieGoal;
  final int? newCalorieGoal;
  final DateTime createdAt;

  WeeklyCheckIn({
    required this.id,
    required this.challengeId,
    required this.checkInDate,
    required this.weekNumber,
    required this.currentWeight,
    this.notes,
    this.progressFeeling,
    this.previousCalorieGoal,
    this.newCalorieGoal,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challengeId': challengeId,
      'checkInDate': checkInDate.toIso8601String(),
      'weekNumber': weekNumber,
      'currentWeight': currentWeight,
      'notes': notes,
      'progressFeeling': progressFeeling,
      'previousCalorieGoal': previousCalorieGoal,
      'newCalorieGoal': newCalorieGoal,
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
      notes: json['notes'],
      progressFeeling: json['progressFeeling'],
      previousCalorieGoal: json['previousCalorieGoal'],
      newCalorieGoal: json['newCalorieGoal'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  WeeklyCheckIn copyWith({
    String? id,
    String? challengeId,
    DateTime? checkInDate,
    int? weekNumber,
    int? currentWeight,
    String? notes,
    String? progressFeeling,
    int? previousCalorieGoal,
    int? newCalorieGoal,
    DateTime? createdAt,
  }) {
    return WeeklyCheckIn(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      checkInDate: checkInDate ?? this.checkInDate,
      weekNumber: weekNumber ?? this.weekNumber,
      currentWeight: currentWeight ?? this.currentWeight,
      notes: notes ?? this.notes,
      progressFeeling: progressFeeling ?? this.progressFeeling,
      previousCalorieGoal: previousCalorieGoal ?? this.previousCalorieGoal,
      newCalorieGoal: newCalorieGoal ?? this.newCalorieGoal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
