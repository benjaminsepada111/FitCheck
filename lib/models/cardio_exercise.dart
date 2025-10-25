// models/cardio_exercise.dart
class CardioExercise {
  final String code;
  final String name;
  final double met;

  CardioExercise({required this.code, required this.name, required this.met});

  // Create from JSON
  factory CardioExercise.fromJson(Map<String, dynamic> json) {
    return CardioExercise(
      code: json['code'] as String,
      name: json['name'] as String,
      met: (json['MET'] as num).toDouble(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {'code': code, 'name': name, 'MET': met};
  }

  // Extract category from activity code
  String get category {
    final codeNum = int.tryParse(code.substring(0, 2)) ?? 0;

    if (codeNum >= 1 && codeNum <= 2) return 'Bicycling';
    if (codeNum == 3) return 'Conditioning Exercise';
    if (codeNum == 4) return 'Dancing';
    if (codeNum == 5) return 'Fishing and Hunting';
    if (codeNum == 6) return 'Home Activities';
    if (codeNum == 7) return 'Home Repair';
    if (codeNum == 8) return 'Inactivity';
    if (codeNum == 9) return 'Lawn and Garden';
    if (codeNum == 10) return 'Miscellaneous';
    if (codeNum == 11) return 'Music Playing';
    if (codeNum == 12) return 'Occupation';
    if (codeNum == 13) return 'Running';
    if (codeNum == 14) return 'Self Care';
    if (codeNum == 15) return 'Sexual Activity';
    if (codeNum == 16) return 'Sports';
    if (codeNum == 17) return 'Transportation';
    if (codeNum == 18) return 'Walking';
    if (codeNum == 19) return 'Water Activities';
    if (codeNum == 20) return 'Winter Activities';
    if (codeNum == 21) return 'Religious Activities';
    if (codeNum == 22) return 'Volunteer Activities';

    return 'Other';
  }

  // Get category display name (for backward compatibility)
  String get categoryDisplayName => category;
}
