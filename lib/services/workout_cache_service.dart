import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/cardio_exercise.dart';

/// Service for caching workout search results in Firebase Firestore
///
/// This service implements a two-tier caching system:
/// 1. User-specific cache (user_workout_cache/{userId}/searches)
/// 2. In-memory cache for current session
///
/// This reduces search time and improves offline functionality
class WorkoutCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static const String _userWorkoutCacheCollection = 'user_workout_cache';

  // In-memory cache
  static List<CardioExercise>? _allExercises;
  static final Map<String, List<CardioExercise>> _sessionCache = {};

  /// Load all exercises from compendium (only done once per session)
  static Future<List<CardioExercise>> _loadAllExercises() async {
    if (_allExercises != null) {
      return _allExercises!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/compendium_2024_activities.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> activitiesJson = jsonData['activities'];

      _allExercises = activitiesJson
          .map((json) => CardioExercise.fromJson(json))
          .toList();

      return _allExercises!;
    } catch (e) {
      print('Error loading exercises: $e');
      return [];
    }
  }

  /// Search for workouts using two-tier cache system
  ///
  /// Flow:
  /// 1. Check session cache (in-memory)
  /// 2. Check user's search cache (Firebase)
  /// 3. Search local compendium and cache result
  static Future<List<CardioExercise>> searchWorkouts(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final normalizedQuery = query.trim().toLowerCase();

    try {
      // Tier 1: Check session cache
      if (_sessionCache.containsKey(normalizedQuery)) {
        print(
          '✓ Found ${_sessionCache[normalizedQuery]!.length} results in session cache',
        );
        return _sessionCache[normalizedQuery]!;
      }

      // Tier 2: Check user's Firebase cache
      final userCachedResults = await _searchUserCache(normalizedQuery);
      if (userCachedResults.isNotEmpty) {
        print('✓ Found ${userCachedResults.length} results in user cache');
        _sessionCache[normalizedQuery] = userCachedResults;
        return userCachedResults;
      }

      // Tier 3: Search local compendium
      final allExercises = await _loadAllExercises();
      final keywords = normalizedQuery
          .split(' ')
          .where((k) => k.isNotEmpty)
          .toList();

      final results = allExercises.where((exercise) {
        final exerciseName = exercise.name.toLowerCase();
        final exerciseCategory = exercise.category.toLowerCase();

        // All keywords must be present
        return keywords.every(
          (keyword) =>
              exerciseName.contains(keyword) ||
              exerciseCategory.contains(keyword),
        );
      }).toList();

      // Sort by relevance
      results.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();

        // Exact match to full query
        if (aName == normalizedQuery) return -1;
        if (bName == normalizedQuery) return 1;

        // Starts with query
        if (aName.startsWith(normalizedQuery) &&
            !bName.startsWith(normalizedQuery))
          return -1;
        if (bName.startsWith(normalizedQuery) &&
            !aName.startsWith(normalizedQuery))
          return 1;

        // Exact match to first keyword
        final firstKeyword = keywords.first;
        if (aName == firstKeyword) return -1;
        if (bName == firstKeyword) return 1;

        // Starts with first keyword
        if (aName.startsWith(firstKeyword) && !bName.startsWith(firstKeyword))
          return -1;
        if (bName.startsWith(firstKeyword) && !aName.startsWith(firstKeyword))
          return 1;

        // Sort by category for grouping
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;

        // Finally, alphabetically by name
        return aName.compareTo(bName);
      });

      // Cache results
      _sessionCache[normalizedQuery] = results;
      _saveToUserCache(normalizedQuery, results);

      print('✓ Found ${results.length} results from compendium');
      return results;
    } catch (e) {
      print('Error searching workouts: $e');
      return [];
    }
  }

  /// Search user's Firebase cache
  static Future<List<CardioExercise>> _searchUserCache(String query) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final doc = await _firestore
          .collection(_userWorkoutCacheCollection)
          .doc(userId)
          .collection('searches')
          .doc(_sanitizeDocId(query))
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null) return [];

      // Check if cache is expired (30 days)
      final timestamp = data['timestamp'] as int?;
      if (timestamp != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheDate);
        if (age.inDays > 30) {
          return []; // Cache expired
        }
      }

      final results = (data['results'] as List<dynamic>?)
          ?.map((json) => CardioExercise.fromJson(json as Map<String, dynamic>))
          .toList();

      return results ?? [];
    } catch (e) {
      print('Error reading user workout cache: $e');
      return [];
    }
  }

  /// Save search results to user's cache
  static Future<void> _saveToUserCache(
    String query,
    List<CardioExercise> exercises,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final cachedExercises = exercises
          .map((exercise) => exercise.toJson())
          .toList();

      await _firestore
          .collection(_userWorkoutCacheCollection)
          .doc(userId)
          .collection('searches')
          .doc(_sanitizeDocId(query))
          .set({
            'query': query,
            'results': cachedExercises,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (e) {
      print('Error saving to user workout cache: $e');
      // Don't throw - cache save failures shouldn't block the flow
    }
  }

  /// Get suggested/popular workouts
  static Future<List<CardioExercise>> getSuggestedWorkouts() async {
    final suggestions = <String>[
      'running',
      'walking',
      'bicycling',
      'swimming',
      'yoga',
    ];

    final allExercises = await _loadAllExercises();
    final suggestedExercises = <CardioExercise>[];

    for (var suggestion in suggestions) {
      final match = allExercises.firstWhere(
        (ex) =>
            ex.name.toLowerCase().contains(suggestion) &&
            ex.name.toLowerCase().split(',').first.trim().toLowerCase() ==
                suggestion,
        orElse: () => allExercises.firstWhere(
          (ex) => ex.name.toLowerCase().contains(suggestion),
          orElse: () => allExercises.first,
        ),
      );
      if (!suggestedExercises.contains(match)) {
        suggestedExercises.add(match);
      }
    }

    return suggestedExercises.take(5).toList();
  }

  /// Sanitize query for use as Firestore document ID
  static String _sanitizeDocId(String query) {
    // Firestore doc IDs can't contain certain characters
    return query
        .replaceAll(RegExp(r'[/\[\]]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Clear session cache (useful for testing or memory management)
  static void clearSessionCache() {
    _sessionCache.clear();
  }

  /// Clear user's Firebase cache
  static Future<void> clearUserCache() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_userWorkoutCacheCollection)
          .doc(userId)
          .collection('searches')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✓ Cleared user workout cache');
    } catch (e) {
      print('Error clearing user workout cache: $e');
    }
  }
}
