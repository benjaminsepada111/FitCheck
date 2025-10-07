class WorkoutModel {
  final String? id;
  final String userId;
  final String exerciseName;
  final int sets;
  final int reps;
  final int duration; // in minutes
  final String? photoUrl;
  final DateTime date;
  final List<bool> completedSets;
  final String? notes;

  WorkoutModel({
    this.id,
    required this.userId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.duration,
    this.photoUrl,
    required this.date,
    required this.completedSets,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'exerciseName': exerciseName,
      'sets': sets,
      'reps': reps,
      'duration': duration,
      'photoUrl': photoUrl,
      'date': date.toIso8601String(),
      'completedSets': completedSets,
      'notes': notes,
    };
  }

  factory WorkoutModel.fromJson(Map<String, dynamic> json, String id) {
    return WorkoutModel(
      id: id,
      userId: json['userId'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? 0,
      duration: json['duration'] ?? 0,
      photoUrl: json['photoUrl'],
      date: DateTime.parse(json['date']),
      completedSets: List<bool>.from(json['completedSets'] ?? []),
      notes: json['notes'],
    );
  }

  WorkoutModel copyWith({
    String? id,
    String? userId,
    String? exerciseName,
    int? sets,
    int? reps,
    int? duration,
    String? photoUrl,
    DateTime? date,
    List<bool>? completedSets,
    String? notes,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      duration: duration ?? this.duration,
      photoUrl: photoUrl ?? this.photoUrl,
      date: date ?? this.date,
      completedSets: completedSets ?? this.completedSets,
      notes: notes ?? this.notes,
    );
  }

  int get completedSetCount => completedSets.where((s) => s).length;
  double get progressPercentage => sets > 0 ? (completedSetCount / sets) * 100 : 0;
}
