class WorkoutModel {
  final String? id;
  final String userId;
  final String challengeId;
  final String exerciseName;
  final int sets;
  final int reps;
  final int duration; // in minutes
  final String? photoUrl;
  final DateTime date;
  final String? notes;

  WorkoutModel({
    this.id,
    required this.userId,
    required this.challengeId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.duration,
    this.photoUrl,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'challengeId': challengeId,
      'exerciseName': exerciseName,
      'sets': sets,
      'reps': reps,
      'duration': duration,
      'photoUrl': photoUrl,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory WorkoutModel.fromJson(Map<String, dynamic> json, String id) {
    return WorkoutModel(
      id: id,
      userId: json['userId'] ?? '',
      challengeId: json['challengeId'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? 0,
      duration: json['duration'] ?? 0,
      photoUrl: json['photoUrl'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }

  WorkoutModel copyWith({
    String? id,
    String? userId,
    String? challengeId,
    String? exerciseName,
    int? sets,
    int? reps,
    int? duration,
    String? photoUrl,
    DateTime? date,
    String? notes,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challengeId: challengeId ?? this.challengeId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      duration: duration ?? this.duration,
      photoUrl: photoUrl ?? this.photoUrl,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}
