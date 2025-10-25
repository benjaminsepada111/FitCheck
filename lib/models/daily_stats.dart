// Daily Statistics Model
// Stores aggregated calorie data for a specific date within a challenge

class DailyStats {
  final String dateId; // Format: YYYYMMDD (e.g., "20251025")
  final DateTime date; // Full date object for easy manipulation
  final int foodCalories; // Total calories consumed from food
  final int cardioCalories; // Calories burned from cardio exercises
  final int
  strengthCalories; // Always 0 (strength doesn't burn measurable calories)
  final int dailyGoal; // User's daily calorie goal
  final DateTime lastUpdated; // Last time this document was updated

  DailyStats({
    required this.dateId,
    required this.date,
    required this.foodCalories,
    required this.cardioCalories,
    this.strengthCalories = 0,
    required this.dailyGoal,
    required this.lastUpdated,
  });

  /// Calculate total calories consumed
  int get totalConsumed => foodCalories;

  /// Calculate total calories burned
  int get totalBurned => cardioCalories + strengthCalories;

  /// Calculate net calories (consumed - burned)
  int get netCalories => totalConsumed - totalBurned;

  /// Calculate remaining calories for the day
  /// Formula: dailyGoal - foodCalories + workoutCalories
  int get remainingCalories => dailyGoal - foodCalories + totalBurned;

  /// Check if user is over their calorie goal
  bool get isOverGoal => netCalories > dailyGoal;

  /// Calculate progress percentage
  double get progressPercentage {
    if (dailyGoal == 0) return 0.0;
    return (netCalories / dailyGoal * 100).clamp(0.0, 200.0);
  }

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'dateId': dateId,
      'date': date.toIso8601String(),
      'foodCalories': foodCalories,
      'cardioCalories': cardioCalories,
      'strengthCalories': strengthCalories,
      'totalConsumed': totalConsumed,
      'totalBurned': totalBurned,
      'netCalories': netCalories,
      'remainingCalories': remainingCalories,
      'dailyGoal': dailyGoal,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from Firebase JSON
  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      dateId: json['dateId'] ?? '',
      date: DateTime.parse(json['date']),
      foodCalories: json['foodCalories'] ?? 0,
      cardioCalories: json['cardioCalories'] ?? 0,
      strengthCalories: json['strengthCalories'] ?? 0,
      dailyGoal: json['dailyGoal'] ?? 2000,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  /// Create a copy with updated fields
  DailyStats copyWith({
    String? dateId,
    DateTime? date,
    int? foodCalories,
    int? cardioCalories,
    int? strengthCalories,
    int? dailyGoal,
    DateTime? lastUpdated,
  }) {
    return DailyStats(
      dateId: dateId ?? this.dateId,
      date: date ?? this.date,
      foodCalories: foodCalories ?? this.foodCalories,
      cardioCalories: cardioCalories ?? this.cardioCalories,
      strengthCalories: strengthCalories ?? this.strengthCalories,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Create empty stats for a date
  factory DailyStats.empty(DateTime date, int dailyGoal) {
    return DailyStats(
      dateId: _formatDateId(date),
      date: DateTime(date.year, date.month, date.day),
      foodCalories: 0,
      cardioCalories: 0,
      strengthCalories: 0,
      dailyGoal: dailyGoal,
      lastUpdated: DateTime.now(),
    );
  }

  /// Helper to format date as YYYYMMDD
  static String _formatDateId(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Helper to get date ID from a date
  static String getDateId(DateTime date) {
    return _formatDateId(date);
  }

  /// Helper to parse date from date ID (YYYYMMDD)
  static DateTime? parseDateId(String dateId) {
    if (dateId.length != 8) return null;
    try {
      final year = int.parse(dateId.substring(0, 4));
      final month = int.parse(dateId.substring(4, 6));
      final day = int.parse(dateId.substring(6, 8));
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'DailyStats(date: $dateId, food: $foodCalories, burned: $totalBurned, remaining: $remainingCalories)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyStats &&
        other.dateId == dateId &&
        other.foodCalories == foodCalories &&
        other.cardioCalories == cardioCalories &&
        other.strengthCalories == strengthCalories &&
        other.dailyGoal == dailyGoal;
  }

  @override
  int get hashCode {
    return Object.hash(
      dateId,
      foodCalories,
      cardioCalories,
      strengthCalories,
      dailyGoal,
    );
  }
}
