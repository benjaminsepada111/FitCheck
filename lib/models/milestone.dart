class Milestone {
  final String id;
  final DateTime date;
  final String? imageUrl; // Firebase Storage URL
  final String? imagePath; // Local file path before upload
  final String? notes;
  final Map<String, dynamic>? metadata; // Weight, measurements, etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  Milestone({
    required this.id,
    required this.date,
    this.imageUrl,
    this.imagePath,
    this.notes,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convenience getters for common metadata
  double? get weight => metadata?['weight']?.toDouble();
  Map<String, double>? get measurements {
    final measurementsData = metadata?['measurements'];
    if (measurementsData is Map<String, dynamic>) {
      return measurementsData.map((key, value) => MapEntry(key, value.toDouble()));
    }
    return null;
  }

  String? get mood => metadata?['mood'];
  int? get energyLevel => metadata?['energyLevel']; // 1-10 scale

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'notes': notes,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'],
      date: DateTime.parse(json['date']),
      imageUrl: json['imageUrl'],
      imagePath: json['imagePath'],
      notes: json['notes'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Milestone copyWith({
    String? id,
    DateTime? date,
    String? imageUrl,
    String? imagePath,
    String? notes,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Milestone(
      id: id ?? this.id,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Milestone(id: $id, date: $date, hasImage: ${imageUrl != null}, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Milestone &&
        other.id == id &&
        other.date == date &&
        other.imageUrl == imageUrl &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(id, date, imageUrl, notes);
  }
}