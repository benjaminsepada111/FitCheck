class Workout {
  final String id;
  final String userId;
  final String exerciseName;
  final String workoutType; // 'cardio' or 'strength'

  // Strength workout fields (optional, used when workoutType = 'strength')
  final int? sets;
  final int? reps;

  // Cardio workout fields (optional, used when workoutType = 'cardio')
  final int? durationMinutes;
  final double? met; // Metabolic Equivalent of Task

  // Common fields
  final String? notes;
  final String? imageUrl; // Cloud Storage URL
  final String? imageBase64; // Legacy field for backward compatibility
  final DateTime timestamp;

  Workout({
    required this.id,
    required this.userId,
    required this.exerciseName,
    required this.workoutType,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.met,
    this.notes,
    this.imageUrl,
    this.imageBase64,
    required this.timestamp,
  });

  // Helper getters
  bool get isCardio => workoutType == 'cardio';
  bool get isStrength => workoutType == 'strength';

  // Calculate calories burned for cardio workouts
  int calculateCaloriesBurned(double userWeight) {
    if (!isCardio || met == null || durationMinutes == null) return 0;
    final hours = durationMinutes! / 60.0;
    return (met! * userWeight * hours).round();
  }

  // Convert workout to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'exerciseName': exerciseName,
      'workoutType': workoutType,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (met != null) 'met': met,
      'notes': notes,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create workout from Firebase map
  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      exerciseName: map['exerciseName'] ?? '',
      workoutType: map['workoutType'] ?? 'strength', // Default to strength for backward compatibility
      sets: map['sets'],
      reps: map['reps'],
      durationMinutes: map['durationMinutes'],
      met: map['met']?.toDouble(),
      notes: map['notes'],
      imageUrl: map['imageUrl'],
      imageBase64: map['imageBase64'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Copy with method for updating fields
  Workout copyWith({
    String? id,
    String? userId,
    String? exerciseName,
    String? workoutType,
    int? sets,
    int? reps,
    int? durationMinutes,
    double? met,
    String? notes,
    String? imageUrl,
    String? imageBase64,
    DateTime? timestamp,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseName: exerciseName ?? this.exerciseName,
      workoutType: workoutType ?? this.workoutType,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      met: met ?? this.met,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
