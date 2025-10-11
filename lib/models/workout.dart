class Workout {
  final String id;
  final String userId;
  final String exerciseName;
  final int sets;
  final int reps;
  final String? notes;
  final String? imageBase64; // Changed from imageUrl to imageBase64
  final DateTime timestamp;

  Workout({
    required this.id,
    required this.userId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.notes,
    this.imageBase64,
    required this.timestamp,
  });

  // Convert workout to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'exerciseName': exerciseName,
      'sets': sets,
      'reps': reps,
      'notes': notes,
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
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      notes: map['notes'],
      imageBase64: map['imageBase64'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Copy with method for updating fields
  Workout copyWith({
    String? id,
    String? userId,
    String? exerciseName,
    int? sets,
    int? reps,
    String? notes,
    String? imageBase64,
    DateTime? timestamp,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      notes: notes ?? this.notes,
      imageBase64: imageBase64 ?? this.imageBase64,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
