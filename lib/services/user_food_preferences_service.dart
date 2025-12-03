import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_models.dart';

/// Service for managing user-specific food preferences:
/// - Recent search queries
/// - Manual entry foods (user-created foods)
class UserFoodPreferencesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static const String _userPreferencesCollection = 'user_food_preferences';
  static const String _recentSearchesSubcollection = 'recent_searches';
  static const String _manualFoodsSubcollection = 'manual_foods';

  // Maximum number of recent searches to keep
  static const int _maxRecentSearches = 20;

  // Maximum number of recent manual foods to keep
  static const int _maxRecentManualFoods = 50;

  /// Save a search query to user's recent searches
  static Future<void> saveRecentSearch(String query) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || query.trim().isEmpty) return;

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) return; // Don't save very short queries

    try {
      final userPrefsRef = _firestore
          .collection(_userPreferencesCollection)
          .doc(userId);

      // Check if this query already exists
      final existingQuery = await userPrefsRef
          .collection(_recentSearchesSubcollection)
          .where('query', isEqualTo: normalizedQuery)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update timestamp of existing query
        await existingQuery.docs.first.reference.update({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Add new query
        await userPrefsRef.collection(_recentSearchesSubcollection).add({
          'query': normalizedQuery,
          'displayQuery': query.trim(), // Keep original casing for display
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Clean up old searches (keep only the most recent N)
        await _cleanupRecentSearches(userId);
      }
    } catch (e) {
      print('Error saving recent search: $e');
      // Don't throw - this is a non-critical operation
    }
  }

  /// Get user's recent search queries (most recent first)
  static Future<List<String>> getRecentSearches({int limit = 10}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_recentSearchesSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['displayQuery'] as String? ?? doc.data()['query'] as String)
          .toList();
    } catch (e) {
      print('Error getting recent searches: $e');
      return [];
    }
  }

  /// Clear all recent searches
  static Future<void> clearRecentSearches() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_recentSearchesSubcollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing recent searches: $e');
      rethrow;
    }
  }

  /// Save a manual entry food to user's collection
  static Future<void> saveManualFood({
    required String foodName,
    required int calories,
    required double servingSize,
    String? imageUrl,
    String unit = 'grams', // 'grams' or 'ml'
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || foodName.trim().isEmpty) return;

    try {
      final userPrefsRef = _firestore
          .collection(_userPreferencesCollection)
          .doc(userId);

      // Generate a unique ID for this manual food (include unit and serving size to differentiate)
      final foodId = _generateFoodId(foodName, calories, unit, servingSize);
      
      // Check if this food already exists
      final existingFood = await userPrefsRef
          .collection(_manualFoodsSubcollection)
          .doc(foodId)
          .get();

      if (existingFood.exists) {
        // Update timestamp to mark as recently used
        await existingFood.reference.update({
          'lastUsed': DateTime.now().millisecondsSinceEpoch,
          'useCount': FieldValue.increment(1),
        });
      } else {
        // Create new manual food entry
        final searchTerms = _generateSearchTerms(foodName);
        
        await userPrefsRef
            .collection(_manualFoodsSubcollection)
            .doc(foodId)
            .set({
          'foodName': foodName.trim(),
          'calories': calories, // Total calories per serving
          'servingSize': servingSize, // Serving size (e.g., 320)
          'unit': unit, // Store the unit (grams or ml)
          'imageUrl': imageUrl,
          'searchTerms': searchTerms,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastUsed': DateTime.now().millisecondsSinceEpoch,
          'useCount': 1,
        });
      }

      // Clean up old manual foods (keep only the most recent N)
      await _cleanupManualFoods(userId);
    } catch (e) {
      print('Error saving manual food: $e');
      // Don't throw - this is a non-critical operation
    }
  }
  
  /// Get serving info for a manual food (for display purposes)
  static Future<Map<String, dynamic>?> getManualFoodServingInfo(int fdcId) async {
    // Manual foods have negative fdcId
    if (fdcId >= 0) return null;
    
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    
    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_manualFoodsSubcollection)
          .get();
      
      for (final doc in snapshot.docs) {
        if (-doc.id.hashCode == fdcId) {
          final data = doc.data();
          return {
            'servingSize': data['servingSize'] ?? 100.0,
            'unit': data['unit'] ?? 'grams',
            'calories': data['calories'] ?? 0,
          };
        }
      }
    } catch (e) {
      print('Error getting manual food serving info: $e');
    }
    return null;
  }

  /// Get user's manual entry foods (most recently used first)
  static Future<List<FoodSearchResult>> getManualFoods({int limit = 20}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_manualFoodsSubcollection)
          .orderBy('lastUsed', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Use a negative fdcId to distinguish manual foods from USDA foods
        final fdcId = -doc.id.hashCode; // Negative ID to avoid conflicts
        
        // Store serving info in calories field temporarily (we'll use it for display)
        // For manual foods, calories field will contain the total calories per serving
        return FoodSearchResult(
          fdcId: fdcId,
          description: data['foodName'] as String,
          calories: (data['calories'] ?? 0).toDouble(), // Total calories per serving
        );
      }).toList();
    } catch (e) {
      print('Error getting manual foods: $e');
      return [];
    }
  }

  /// Search user's manual foods by query
  static Future<List<FoodSearchResult>> searchManualFoods(String query) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || query.trim().isEmpty) return [];

    final normalizedQuery = query.trim().toLowerCase();

    try {
      // Get all manual foods and filter in memory
      // (Firestore doesn't support full-text search easily)
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_manualFoodsSubcollection)
          .get();

      final results = <FoodSearchResult>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final foodName = (data['foodName'] as String? ?? '').toLowerCase();
        final searchTerms = (data['searchTerms'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();

        // Check if query matches food name or search terms
        if (foodName.contains(normalizedQuery) ||
            searchTerms.any((term) => term.contains(normalizedQuery))) {
          final fdcId = -doc.id.hashCode;
          results.add(FoodSearchResult(
            fdcId: fdcId,
            description: data['foodName'] as String,
            calories: (data['calories'] ?? 0).toDouble(), // Total calories per serving
          ));
        }
      }

      // Sort by relevance (exact match first, then by last used)
      results.sort((a, b) {
        final aName = a.description.toLowerCase();
        final bName = b.description.toLowerCase();
        
        // Exact match gets priority
        if (aName == normalizedQuery) return -1;
        if (bName == normalizedQuery) return 1;
        
        // Starts with query gets priority
        if (aName.startsWith(normalizedQuery) && !bName.startsWith(normalizedQuery)) return -1;
        if (bName.startsWith(normalizedQuery) && !aName.startsWith(normalizedQuery)) return 1;
        
        return 0;
      });

      return results;
    } catch (e) {
      print('Error searching manual foods: $e');
      return [];
    }
  }

  /// Delete a manual food entry
  static Future<void> deleteManualFood({
    required String foodName,
    required int calories,
    required double servingSize,
    required String unit,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final foodId = _generateFoodId(foodName, calories, unit, servingSize);
      await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_manualFoodsSubcollection)
          .doc(foodId)
          .delete();
    } catch (e) {
      print('Error deleting manual food: $e');
      rethrow;
    }
  }

  /// Clean up old recent searches (keep only the most recent N)
  static Future<void> _cleanupRecentSearches(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_recentSearchesSubcollection)
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.length > _maxRecentSearches) {
        final toDelete = snapshot.docs.sublist(_maxRecentSearches);
        final batch = _firestore.batch();
        for (final doc in toDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error cleaning up recent searches: $e');
    }
  }

  /// Clean up old manual foods (keep only the most recent N)
  static Future<void> _cleanupManualFoods(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_userPreferencesCollection)
          .doc(userId)
          .collection(_manualFoodsSubcollection)
          .orderBy('lastUsed', descending: true)
          .get();

      if (snapshot.docs.length > _maxRecentManualFoods) {
        final toDelete = snapshot.docs.sublist(_maxRecentManualFoods);
        final batch = _firestore.batch();
        for (final doc in toDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error cleaning up manual foods: $e');
    }
  }

  /// Generate a unique ID for a manual food based on name, calories, unit, and serving size
  static String _generateFoodId(String foodName, int calories, String unit, double servingSize) {
    // Create a consistent ID from food name, calories, unit, and serving size
    final normalized = foodName.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    return '${normalized}_${calories}_${servingSize}_$unit'.replaceAll(RegExp(r'\s+'), '_');
  }

  /// Generate search terms for a food name
  static List<String> _generateSearchTerms(String foodName) {
    final terms = <String>[];
    final normalized = foodName.toLowerCase().trim();

    // Add the full name
    terms.add(normalized);

    // Add individual words
    final words = normalized.split(RegExp(r'\s+'));
    terms.addAll(words);

    // Add prefixes for partial matching (minimum 3 characters)
    for (final word in words) {
      if (word.length >= 3) {
        for (int i = 3; i <= word.length; i++) {
          terms.add(word.substring(0, i));
        }
      }
    }

    return terms;
  }
}

