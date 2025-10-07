class WorkoutLog {
  final String id;
  final DateTime date;
  final String workoutType; // cardio, strength, flexibility, sports, etc.
  final List<WorkoutEntry> entries;
  final String? imageUrl; // Firebase Storage URL for workout photo
  final String? imagePath; // Local file path before upload
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutLog({
    required this.id,
    required this.date,
    required this.workoutType,
    required this.entries,
    this.imageUrl,
    this.imagePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculate total calories burned for this workout
  double get totalCaloriesBurned {
    return entries.fold(0.0, (sum, entry) => sum + entry.caloriesBurned);
  }

  // Calculate total duration in minutes
  int get totalDuration {
    return entries.fold(0, (sum, entry) => sum + entry.durationMinutes);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'workoutType': workoutType,
      'entries': entries.map((e) => e.toJson()).toList(),
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'],
      date: DateTime.parse(json['date']),
      workoutType: json['workoutType'],
      entries: (json['entries'] as List<dynamic>)
          .map((e) => WorkoutEntry.fromJson(e))
          .toList(),
      imageUrl: json['imageUrl'],
      imagePath: json['imagePath'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  WorkoutLog copyWith({
    String? id,
    DateTime? date,
    String? workoutType,
    List<WorkoutEntry>? entries,
    String? imageUrl,
    String? imagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutLog(
      id: id ?? this.id,
      date: date ?? this.date,
      workoutType: workoutType ?? this.workoutType,
      entries: entries ?? this.entries,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WorkoutEntry {
  final String id;
  final String exerciseName;
  final int durationMinutes;
  final double caloriesBurned;
  final int? sets;
  final int? reps;
  final double? weight; // in kg
  final double? distance; // in km
  final String? intensity; // low, moderate, high

  WorkoutEntry({
    required this.id,
    required this.exerciseName,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.sets,
    this.reps,
    this.weight,
    this.distance,
    this.intensity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'distance': distance,
      'intensity': intensity,
    };
  }

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutEntry(
      id: json['id'],
      exerciseName: json['exerciseName'],
      durationMinutes: json['durationMinutes'],
      caloriesBurned: json['caloriesBurned'].toDouble(),
      sets: json['sets'],
      reps: json['reps'],
      weight: json['weight']?.toDouble(),
      distance: json['distance']?.toDouble(),
      intensity: json['intensity'],
    );
  }

  WorkoutEntry copyWith({
    String? id,
    String? exerciseName,
    int? durationMinutes,
    double? caloriesBurned,
    int? sets,
    int? reps,
    double? weight,
    double? distance,
    String? intensity,
  }) {
    return WorkoutEntry(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      distance: distance ?? this.distance,
      intensity: intensity ?? this.intensity,
    );
  }
}

// Predefined workout types
class WorkoutType {
  static const String cardio = 'Cardio';
  static const String strength = 'Strength';
  static const String flexibility = 'Flexibility';
  static const String sports = 'Sports';
  static const String yoga = 'Yoga';
  static const String hiit = 'HIIT';
  static const String other = 'Other';

  static List<String> get all => [
        cardio,
        strength,
        flexibility,
        sports,
        yoga,
        hiit,
        other,
      ];

  static String getIcon(String type) {
    switch (type) {
      case cardio:
        return '🏃';
      case strength:
        return '💪';
      case flexibility:
        return '🧘';
      case sports:
        return '⚽';
      case yoga:
        return '🧘‍♀️';
      case hiit:
        return '🔥';
      default:
        return '🏋️';
    }
  }
}

// Common exercises for quick logging with MET values
class CommonExercises {
  // MET (Metabolic Equivalent of Task) values for exercises
  // MET represents energy cost as a multiple of resting metabolic rate
  static const Map<String, Map<String, dynamic>> cardio = {
    'Running': {'met': 8.0, 'description': 'Moderate pace'},
    'Walking': {'met': 3.5, 'description': 'Brisk walking'},
    'Cycling': {'met': 6.5, 'description': 'Moderate effort'},
    'Swimming': {'met': 8.0, 'description': 'Moderate effort'},
    'Jump Rope': {'met': 12.0, 'description': 'Moderate pace'},
    'Rowing': {'met': 7.0, 'description': 'Moderate effort'},
  };

  static const Map<String, Map<String, dynamic>> strength = {
    'Push-ups': {'met': 3.8, 'description': 'Moderate effort'},
    'Pull-ups': {'met': 8.0, 'description': 'Vigorous effort'},
    'Squats': {'met': 5.0, 'description': 'Moderate effort'},
    'Bench Press': {'met': 6.0, 'description': 'Moderate effort'},
    'Deadlifts': {'met': 6.0, 'description': 'Moderate effort'},
    'Lunges': {'met': 4.0, 'description': 'Moderate effort'},
  };

  static const Map<String, Map<String, dynamic>> flexibility = {
    'Yoga': {'met': 3.0, 'description': 'Hatha yoga'},
    'Stretching': {'met': 2.5, 'description': 'General stretching'},
    'Pilates': {'met': 3.5, 'description': 'General'},
  };

  static const Map<String, Map<String, dynamic>> sports = {
    'Basketball': {'met': 6.5, 'description': 'General play'},
    'Soccer': {'met': 7.0, 'description': 'General play'},
    'Tennis': {'met': 7.0, 'description': 'Singles'},
    'Volleyball': {'met': 4.0, 'description': 'General play'},
  };

  static Map<String, Map<String, dynamic>> getExercisesForType(String type) {
    switch (type) {
      case WorkoutType.cardio:
        return cardio;
      case WorkoutType.strength:
        return strength;
      case WorkoutType.flexibility:
        return flexibility;
      case WorkoutType.sports:
        return sports;
      default:
        return {};
    }
  }

  /// Get MET value for an exercise by name
  static double? getMETValue(String exerciseName) {
    // Search all exercise categories
    final allExercises = [cardio, strength, flexibility, sports];
    for (final category in allExercises) {
      if (category.containsKey(exerciseName)) {
        return category[exerciseName]?['met']?.toDouble();
      }
    }
    return null;
  }
}
