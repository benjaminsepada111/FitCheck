// services/user_data_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_data.dart';
import 'calorie_calculator.dart';

class UserDataService {
  static const String _userDataKey = 'user_data';
  static UserData? _cachedUserData;

  /// Save user data to local storage
  static Future<bool> saveUserData(UserData userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(userData.toJson());
      final success = await prefs.setString(_userDataKey, jsonString);

      if (success) {
        _cachedUserData = userData;
      }

      return success;
    } catch (e) {
      print('Error saving user data: $e');
      return false;
    }
  }

  /// Load user data from local storage
  static Future<UserData?> loadUserData() async {
    // Return cached data if available
    if (_cachedUserData != null) {
      return _cachedUserData;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_userDataKey);

      if (jsonString != null) {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedUserData = UserData.fromJson(jsonMap);
        return _cachedUserData;
      }

      return null;
    } catch (e) {
      print('Error loading user data: $e');
      return null;
    }
  }

  /// Update specific field in user data
  static Future<bool> updateUserData({
    String? gender,
    DateTime? birthDate,
    int? weight,
    int? height,
    String? activityLevel,
    String? goal,
    double? goalAdjustment,
  }) async {
    try {
      final currentData = await loadUserData() ?? UserData();

      final updatedData = currentData.copyWith(
        gender: gender,
        birthDate: birthDate,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        goal: goal,
        goalAdjustment: goalAdjustment,
      );

      return await saveUserData(updatedData);
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  /// Clear all user data
  static Future<bool> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUserData = null;
      return await prefs.remove(_userDataKey);
    } catch (e) {
      print('Error clearing user data: $e');
      return false;
    }
  }

  /// Check if user has completed profile setup
  static Future<bool> isProfileComplete() async {
    final userData = await loadUserData();
    return userData?.isComplete ?? false;
  }

  /// Get completion percentage of profile
  static Future<double> getProfileCompletionPercentage() async {
    final userData = await loadUserData();
    if (userData == null) return 0.0;

    int completedFields = 0;
    int totalFields = 6; // gender, birthDate, weight, height, activityLevel, goal

    if (userData.gender != null) completedFields++;
    if (userData.birthDate != null) completedFields++;
    if (userData.weight != null) completedFields++;
    if (userData.height != null) completedFields++;
    if (userData.activityLevel != null) completedFields++;
    if (userData.goal != null) completedFields++;

    return completedFields / totalFields;
  }

  /// Get list of missing profile fields
  static Future<List<String>> getMissingFields() async {
    final userData = await loadUserData();
    final missingFields = <String>[];

    if (userData?.gender == null) missingFields.add('Gender');
    if (userData?.birthDate == null) missingFields.add('Birth Date');
    if (userData?.weight == null) missingFields.add('Weight');
    if (userData?.height == null) missingFields.add('Height');
    if (userData?.activityLevel == null) missingFields.add('Activity Level');
    if (userData?.goal == null) missingFields.add('Goal');

    return missingFields;
  }

  /// Force refresh cached data
  static Future<UserData?> refreshUserData() async {
    _cachedUserData = null;
    return await loadUserData();
  }

  /// Export user data as JSON string for backup
  static Future<String?> exportUserData() async {
    try {
      final userData = await loadUserData();
      if (userData == null) return null;

      return jsonEncode(userData.toJson());
    } catch (e) {
      print('Error exporting user data: $e');
      return null;
    }
  }

  /// Import user data from JSON string
  static Future<bool> importUserData(String jsonString) async {
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final userData = UserData.fromJson(jsonMap);
      return await saveUserData(userData);
    } catch (e) {
      print('Error importing user data: $e');
      return false;
    }
  }

  /// Get daily calorie goal using CalorieCalculator
  static Future<int> getDailyCalorieGoal() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.calculateDailyCalorieGoal(userData);
      }
      return 2000; // Default fallback
    } catch (e) {
      print('Error calculating daily calorie goal: $e');
      return 2000;
    }
  }

  /// Get daily water goal using CalorieCalculator
  static Future<int> getDailyWaterGoal() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.calculateDailyWaterGoal(userData);
      }
      return 8; // Default fallback
    } catch (e) {
      print('Error calculating daily water goal: $e');
      return 8;
    }
  }

  /// Get calorie breakdown using CalorieCalculator
  static Future<Map<String, dynamic>?> getCalorieBreakdown() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.getCalorieBreakdown(userData);
      }
      return null;
    } catch (e) {
      print('Error getting calorie breakdown: $e');
      return null;
    }
  }

  /// Get macro breakdown using CalorieCalculator
  static Future<Map<String, dynamic>?> getMacroBreakdown() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.calculateMacros(userData);
      }
      return null;
    } catch (e) {
      print('Error getting macro breakdown: $e');
      return null;
    }
  }

  /// Get predicted weekly weight change
  static Future<double> getPredictedWeeklyWeightChange() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.predictWeeklyWeightChange(userData);
      }
      return 0.0;
    } catch (e) {
      print('Error calculating predicted weight change: $e');
      return 0.0;
    }
  }

  /// Get calorie range for current goal
  static Future<Map<String, int>?> getCalorieRange() async {
    try {
      final userData = await loadUserData();
      if (userData != null && CalorieCalculator.isValidUserData(userData)) {
        return CalorieCalculator.getCalorieRange(userData);
      }
      return null;
    } catch (e) {
      print('Error getting calorie range: $e');
      return null;
    }
  }
}