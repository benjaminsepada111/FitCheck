class Challenge {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyCalorieGoal;
  final int dailyWaterGoal;
  final String notes;
  final DateTime createdAt;

  Challenge({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.dailyCalorieGoal,
    required this.dailyWaterGoal,
    required this.notes,
    required this.createdAt,
  });

  // Optional: Add convenience methods
  Duration get duration => endDate.difference(startDate);

  bool isActiveOn(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(endDate.add(const Duration(days: 1)));
  }

  @override
  String toString() {
    return 'Challenge(title: $title, startDate: $startDate, endDate: $endDate)';
  }
}