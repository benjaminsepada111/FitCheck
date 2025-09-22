import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Model for storing food entries
class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final String mealType;
  final DateTime dateLogged;
  final double? grams;
  final Map<String, double>? nutrition; // protein, carbs, fat, etc.

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.mealType,
    required this.dateLogged,
    this.grams,
    this.nutrition,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'mealType': mealType,
      'dateLogged': dateLogged.toIso8601String(),
      'grams': grams,
      'nutrition': nutrition,
    };
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'],
      name: json['name'],
      calories: json['calories'],
      mealType: json['mealType'],
      dateLogged: DateTime.parse(json['dateLogged']),
      grams: json['grams']?.toDouble(),
      nutrition: json['nutrition'] != null
          ? Map<String, double>.from(json['nutrition'])
          : null,
    );
  }
}

// Service for managing food storage and recommendations
class FoodStorageService {
  static const String _foodEntriesKey = 'food_entries';
  static const String _recommendationsKey = 'meal_recommendations';

  // Get current meal type based on time
  static String getCurrentMealType() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) {
      return 'Breakfast';
    } else if (hour >= 11 && hour < 15) {
      return 'Lunch';
    } else if (hour >= 15 && hour < 18) {
      return 'Snack';
    } else {
      return 'Dinner';
    }
  }

  // Store a food entry
  static Future<void> storeFoodEntry(FoodEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existingEntries = await getFoodEntriesForDate(entry.dateLogged);
    existingEntries.add(entry);

    final dateKey = '${_foodEntriesKey}_${_formatDate(entry.dateLogged)}';
    final jsonList = existingEntries.map((e) => e.toJson()).toList();
    await prefs.setString(dateKey, jsonEncode(jsonList));
  }

  // Get food entries for a specific date
  static Future<List<FoodEntry>> getFoodEntriesForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${_foodEntriesKey}_${_formatDate(date)}';
    final jsonString = prefs.getString(dateKey);

    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => FoodEntry.fromJson(json)).toList();
  }

  // Get food entries for a specific meal type and date
  static Future<List<FoodEntry>> getFoodEntriesForMeal(String mealType, DateTime date) async {
    final allEntries = await getFoodEntriesForDate(date);
    return allEntries.where((entry) => entry.mealType == mealType).toList();
  }

  // Remove a food entry
  static Future<void> removeFoodEntry(String entryId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getFoodEntriesForDate(date);
    entries.removeWhere((entry) => entry.id == entryId);

    final dateKey = '${_foodEntriesKey}_${_formatDate(date)}';
    final jsonList = entries.map((e) => e.toJson()).toList();
    await prefs.setString(dateKey, jsonEncode(jsonList));
  }

  // Get total calories for a specific meal
  static Future<int> getTotalCaloriesForMeal(String mealType, DateTime date) async {
    final entries = await getFoodEntriesForMeal(mealType, date);
    return entries.fold<int>(0, (total, entry) => total + entry.calories);
  }

// Get total calories for the entire day
  static Future<int> getTotalCaloriesForDay(DateTime date) async {
    final entries = await getFoodEntriesForDate(date);
    return entries.fold<int>(0, (total, entry) => total + entry.calories);
  }


  // Store meal recommendations based on user's logging history
  static Future<void> updateMealRecommendations(String mealType, String foodName) async {
    final prefs = await SharedPreferences.getInstance();
    final recommendationsJson = prefs.getString(_recommendationsKey);

    Map<String, List<String>> recommendations = {};
    if (recommendationsJson != null) {
      final decoded = jsonDecode(recommendationsJson) as Map<String, dynamic>;
      recommendations = decoded.map((key, value) =>
          MapEntry(key, List<String>.from(value))
      );
    }

    recommendations[mealType] ??= [];
    if (!recommendations[mealType]!.contains(foodName)) {
      recommendations[mealType]!.add(foodName);

      // Keep only the last 10 recommendations per meal
      if (recommendations[mealType]!.length > 10) {
        recommendations[mealType]!.removeRange(0, recommendations[mealType]!.length - 10);
      }
    }

    await prefs.setString(_recommendationsKey, jsonEncode(recommendations));
  }

  // Get meal recommendations for current time
  static Future<List<String>> getMealRecommendations([String? mealType]) async {
    final prefs = await SharedPreferences.getInstance();
    final recommendationsJson = prefs.getString(_recommendationsKey);

    if (recommendationsJson == null) {
      return _getDefaultRecommendations(mealType ?? getCurrentMealType());
    }

    final decoded = jsonDecode(recommendationsJson) as Map<String, dynamic>;
    final recommendations = decoded.map((key, value) =>
        MapEntry(key, List<String>.from(value))
    );

    final currentMeal = mealType ?? getCurrentMealType();
    return recommendations[currentMeal] ?? _getDefaultRecommendations(currentMeal);
  }

  // Default recommendations when no history exists
  static List<String> _getDefaultRecommendations(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return ['Oatmeal', 'Scrambled eggs', 'Greek yogurt', 'Banana', 'Whole wheat toast'];
      case 'Lunch':
        return ['Grilled chicken salad', 'Quinoa bowl', 'Sandwich', 'Soup', 'Rice and beans'];
      case 'Snack':
        return ['Apple', 'Nuts', 'Yogurt', 'Crackers', 'Fruit smoothie'];
      case 'Dinner':
        return ['Grilled salmon', 'Pasta', 'Stir fry', 'Roasted vegetables', 'Lean beef'];
      default:
        return [];
    }
  }

  // Get nutrition summary for a day
  static Future<Map<String, double>> getNutritionSummary(DateTime date) async {
    final entries = await getFoodEntriesForDate(date);

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final entry in entries) {
      totalCalories += entry.calories.toDouble();
      if (entry.nutrition != null) {
        totalProtein += entry.nutrition!['protein'] ?? 0;
        totalCarbs += entry.nutrition!['carbs'] ?? 0;
        totalFat += entry.nutrition!['totalFat'] ?? 0;
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'totalFat': totalFat,
    };
  }

  // Helper method to format date for storage keys
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Clear all food entries (for testing or reset functionality)
  static Future<void> clearAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_foodEntriesKey)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}