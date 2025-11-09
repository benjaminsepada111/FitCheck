// services/user_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_data.dart';
import 'calorie_calculator.dart';

class UserDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static UserData? _cachedUserData;
  static String? _cachedUserId;

  static const String _usersCollection = 'users';

  /// Save user data to Firebase Firestore
  static Future<bool> saveUserData(UserData userData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc('data')
          .set(userData.toJson(), SetOptions(merge: true));

      _cachedUserData = userData;
      _cachedUserId = user.uid;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load user data from Firebase Firestore
  static Future<UserData?> loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Return cached data if it's for the same user
      if (_cachedUserData != null && _cachedUserId == user.uid) {
        return _cachedUserData;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc('data')
          .get();

      if (doc.exists && doc.data() != null) {
        final userData = UserData.fromJson(doc.data()!);
        _cachedUserData = userData;
        _cachedUserId = user.uid;
        return userData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update specific field in user data
  static Future<bool> updateUserData({
    String? name,
    String? bio,
    String? gender,
    DateTime? birthDate,
    int? weight,
    int? height,
    String? activityLevel,
    String? goal,
    double? goalAdjustment,
    DateTime? startDate,
    String? profilePictureUrl,
  }) async {
    try {
      final currentData = await loadUserData() ?? UserData();

      final updatedData = currentData.copyWith(
        name: name,
        bio: bio,
        gender: gender,
        birthDate: birthDate,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        goal: goal,
        goalAdjustment: goalAdjustment,
        startDate: startDate,
        profilePictureUrl: profilePictureUrl,
      );

      return await saveUserData(updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Clear all user data from Firebase
  static Future<bool> clearUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc('data')
          .delete();

      _cachedUserData = null;
      _cachedUserId = null;
      return true;
    } catch (e) {
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
    _cachedUserId = null;
    return await loadUserData();
  }

  /// Check if current user has user data
  static Future<bool> hasUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection('profile')
          .doc('data')
          .get();

      return doc.exists && doc.data() != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current user ID
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Listen to user data changes in real-time
  static Stream<UserData?> getUserDataStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection('profile')
        .doc('data')
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        final userData = UserData.fromJson(doc.data()!);
        _cachedUserData = userData;
        _cachedUserId = user.uid;
        return userData;
      }
      return null;
    });
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
      return 2000;
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
      return null;
    }
  }
}