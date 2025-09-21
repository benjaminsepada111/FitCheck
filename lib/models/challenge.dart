// models/challenge.dart
import '../services/user_data_service.dart';


class Challenge {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyCalorieGoal;
  final int dailyWaterGoal;
  final String notes;

  Challenge({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.dailyCalorieGoal,
    required this.dailyWaterGoal,
    this.notes = '',
  });

  /// Create a challenge with automatically calculated goals
  static Future<Challenge> createWithCalculatedGoals({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String notes = '',
    int? customCalorieGoal, // Override calculated goal if needed
    int? customWaterGoal,   // Override calculated goal if needed
  }) async {
    int calorieGoal = customCalorieGoal ?? await UserDataService.getDailyCalorieGoal();
    int waterGoal = customWaterGoal ?? await UserDataService.getDailyWaterGoal();

    return Challenge(
      title: title,
      startDate: startDate,
      endDate: endDate,
      dailyCalorieGoal: calorieGoal,
      dailyWaterGoal: waterGoal,
      notes: notes,
    );
  }

  /// Get challenge duration in days
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Check if challenge is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Check if challenge is completed
  bool get isCompleted {
    return DateTime.now().isAfter(endDate.add(const Duration(days: 1)));
  }

  /// Check if challenge is upcoming
  bool get isUpcoming {
    return DateTime.now().isBefore(startDate);
  }

  /// Get challenge status
  String get status {
    if (isCompleted) return 'Completed';
    if (isActive) return 'Active';
    return 'Upcoming';
  }

  /// Calculate progress percentage (0-100)
  int calculateProgress() {
    final now = DateTime.now();

    if (isUpcoming) return 0;
    if (isCompleted) return 100;

    final totalDays = durationInDays;
    final daysPassed = now.difference(startDate).inDays + 1;

    if (daysPassed <= 0) return 0;
    if (daysPassed >= totalDays) return 100;

    return ((daysPassed / totalDays) * 100).round();
  }

  /// Get days remaining in challenge
  int get daysRemaining {
    if (isCompleted) return 0;
    if (isUpcoming) return durationInDays;

    final now = DateTime.now();
    final remaining = endDate.difference(now).inDays + 1;
    return remaining > 0 ? remaining : 0;
  }

  /// Get days since challenge started
  int get daysSinceStart {
    if (isUpcoming) return 0;

    final now = DateTime.now();
    final days = now.difference(startDate).inDays + 1;
    return days > 0 ? days : 0;
  }

  /// Get user's calorie breakdown for this challenge
  Future<Map<String, dynamic>?> getCalorieBreakdown() async {
    return await UserDataService.getCalorieBreakdown();
  }

  /// Get user's macro breakdown for this challenge
  Future<Map<String, dynamic>?> getMacroBreakdown() async {
    return await UserDataService.getMacroBreakdown();
  }

  /// Get predicted weekly weight change for this challenge
  Future<double> getPredictedWeeklyWeightChange() async {
    return await UserDataService.getPredictedWeeklyWeightChange();
  }

  /// Get calorie range recommendations
  Future<Map<String, int>?> getCalorieRange() async {
    return await UserDataService.getCalorieRange();
  }

  /// Calculate total calories for entire challenge
  int get totalCalorieGoal {
    return dailyCalorieGoal * durationInDays;
  }

  /// Calculate total water for entire challenge
  int get totalWaterGoal {
    return dailyWaterGoal * durationInDays;
  }

  /// Check if challenge dates are valid
  bool get hasValidDates {
    return startDate.isBefore(endDate) || startDate.isAtSameMomentAs(endDate);
  }

  /// Get a formatted date range string
  String get dateRangeString {
    final startFormatted = '${startDate.month}/${startDate.day}/${startDate.year}';
    final endFormatted = '${endDate.month}/${endDate.day}/${endDate.year}';
    return '$startFormatted - $endFormatted';
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'dailyCalorieGoal': dailyCalorieGoal,
      'dailyWaterGoal': dailyWaterGoal,
      'notes': notes,
    };
  }

  /// Create from JSON
  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      title: json['title'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      dailyCalorieGoal: json['dailyCalorieGoal'],
      dailyWaterGoal: json['dailyWaterGoal'],
      notes: json['notes'] ?? '',
    );
  }

  /// Create a copy with updated values
  Challenge copyWith({
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? dailyCalorieGoal,
    int? dailyWaterGoal,
    String? notes,
  }) {
    return Challenge(
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      dailyWaterGoal: dailyWaterGoal ?? this.dailyWaterGoal,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Challenge(title: $title, startDate: $startDate, endDate: $endDate, status: $status, progress: ${calculateProgress()}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Challenge &&
        other.title == title &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.dailyCalorieGoal == dailyCalorieGoal &&
        other.dailyWaterGoal == dailyWaterGoal &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      startDate,
      endDate,
      dailyCalorieGoal,
      dailyWaterGoal,
      notes,
    );
  }
}