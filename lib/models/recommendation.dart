import 'package:flutter/material.dart';

enum RecommendationType {
  calories,
  workouts,
  meals,
  photos,
  water,
  sleep,
  consistency,
}

class Recommendation {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final RecommendationType type;
  final int priority; // Higher = more important (0-10)

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconCodePoint': icon.codePoint,
      'type': type.toString(),
      'priority': priority,
    };
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      type: RecommendationType.values.firstWhere(
            (e) => e.toString() == json['type'],
        orElse: () => RecommendationType.consistency,
      ),
      priority: json['priority'],
    );
  }
}

class WeeklyPerformanceData {
  final double avgCaloriesConsumed;
  final double avgCalorieDeviation; // How far from goal (+/-)
  final int workoutCount;
  final int cardioCount;
  final int strengthCount;
  final double mealLoggingRate; // % of days with meals logged (0.0-1.0)
  final int photoCount;
  final int totalActiveDays; // Days with any activity logged
  final int daysInWeek; // Actual days in this week (might be < 7)

  WeeklyPerformanceData({
    required this.avgCaloriesConsumed,
    required this.avgCalorieDeviation,
    required this.workoutCount,
    required this.cardioCount,
    required this.strengthCount,
    required this.mealLoggingRate,
    required this.photoCount,
    required this.totalActiveDays,
    required this.daysInWeek,
  });
}