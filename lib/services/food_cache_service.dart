import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_models.dart';
import 'usda_api_service.dart';

/// Service for caching food search results in Firebase Firestore
///
/// This service implements a three-tier caching system:
/// 1. User-specific cache (user_search_cache/{userId}/searches)
/// 2. Global cache (foods)
/// 3. USDA API (fallback when not found in cache)
///
/// This reduces API calls and improves offline functionality
class FoodCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static const String _globalFoodsCollection = 'foods';
  static const String _userSearchCacheCollection = 'user_search_cache';

  // Cache expiration (30 days)
  static const Duration _cacheExpiration = Duration(days: 30);

  /// Search for foods using three-tier cache system
  ///
  /// Flow:
  /// 1. Check user's search cache
  /// 2. Check global foods cache
  /// 3. Fetch from USDA API if not found
  /// 4. Save results to both caches
  static Future<List<FoodSearchResult>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final normalizedQuery = query.trim().toLowerCase();

    try {
      // Tier 1: Check user's search cache
      final userCachedResults = await _searchUserCache(normalizedQuery);
      if (userCachedResults.isNotEmpty) {
        print('✓ Found ${userCachedResults.length} results in user cache');
        return userCachedResults;
      }

      // Tier 2: Check global foods cache
      final globalCachedResults = await _searchGlobalCache(normalizedQuery);
      if (globalCachedResults.isNotEmpty) {
        print('✓ Found ${globalCachedResults.length} results in global cache');

        // Save to user cache for faster future access
        await _saveToUserCache(normalizedQuery, globalCachedResults);

        return globalCachedResults;
      }

      // Tier 3: Fetch from USDA API
      print('→ Fetching from USDA API...');
      final apiResponse = await USDAApiService.searchFoods(
        query: query,
        pageSize: 15,
      );

      if (apiResponse.foods.isEmpty) {
        return [];
      }

      // Save to both caches for future use
      await Future.wait([
        _saveToGlobalCache(apiResponse.foods),
        _saveToUserCache(normalizedQuery, apiResponse.foods),
      ]);

      print('✓ Saved ${apiResponse.foods.length} results to cache');
      return apiResponse.foods;

    } catch (e) {
      print('Error in food cache service: $e');

      // If cache fails, try USDA API directly as fallback
      try {
        final apiResponse = await USDAApiService.searchFoods(
          query: query,
          pageSize: 15,
        );
        return apiResponse.foods;
      } catch (apiError) {
        print('Error fetching from USDA API: $apiError');
        rethrow;
      }
    }
  }

  /// Search user's personal cache
  static Future<List<FoodSearchResult>> _searchUserCache(String query) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final cacheDoc = await _firestore
          .collection(_userSearchCacheCollection)
          .doc(userId)
          .collection('searches')
          .doc(_sanitizeDocId(query))
          .get();

      if (!cacheDoc.exists) return [];

      final data = cacheDoc.data();
      if (data == null) return [];

      // Check if cache is expired
      final timestamp = data['timestamp'] as int?;
      if (timestamp != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheDate) > _cacheExpiration) {
          // Cache expired, delete it
          await cacheDoc.reference.delete();
          return [];
        }
      }

      final results = (data['results'] as List<dynamic>?)
          ?.map((item) => CachedFood.fromJson(item).toFoodSearchResult())
          .toList() ?? [];

      return results;
    } catch (e) {
      print('Error searching user cache: $e');
      return [];
    }
  }

  /// Search global foods cache
  static Future<List<FoodSearchResult>> _searchGlobalCache(String query) async {
    try {
      // Search by name field with case-insensitive partial matching
      final snapshot = await _firestore
          .collection(_globalFoodsCollection)
          .where('searchTerms', arrayContains: query)
          .limit(15)
          .get();

      if (snapshot.docs.isEmpty) {
        // Try broader search with query prefix
        final broadSnapshot = await _firestore
            .collection(_globalFoodsCollection)
            .orderBy('name')
            .startAt([query])
            .endAt(['$query\uf8ff'])
            .limit(15)
            .get();

        if (broadSnapshot.docs.isEmpty) return [];

        return broadSnapshot.docs
            .map((doc) => CachedFood.fromJson(doc.data()).toFoodSearchResult())
            .toList();
      }

      return snapshot.docs
          .map((doc) => CachedFood.fromJson(doc.data()).toFoodSearchResult())
          .toList();
    } catch (e) {
      print('Error searching global cache: $e');
      return [];
    }
  }

  /// Save foods to global cache
  static Future<void> _saveToGlobalCache(List<FoodSearchResult> foods) async {
    try {
      final batch = _firestore.batch();

      for (final food in foods) {
        final docRef = _firestore
            .collection(_globalFoodsCollection)
            .doc(food.fdcId.toString());

        // Generate search terms for the food
        final searchTerms = _generateSearchTerms(food.description);

        final cachedFood = CachedFood.fromFoodSearchResult(
          food,
          source: 'usda',
          searchTerms: searchTerms.join(','),
        );

        batch.set(docRef, {
          ...cachedFood.toJson(),
          'searchTerms': searchTerms,
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error saving to global cache: $e');
      // Don't throw - cache save failures shouldn't block the flow
    }
  }

  /// Save search results to user's cache
  static Future<void> _saveToUserCache(
    String query,
    List<FoodSearchResult> foods,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final cachedFoods = foods
          .map((food) => CachedFood.fromFoodSearchResult(food, source: 'usda'))
          .map((cached) => cached.toJson())
          .toList();

      await _firestore
          .collection(_userSearchCacheCollection)
          .doc(userId)
          .collection('searches')
          .doc(_sanitizeDocId(query))
          .set({
        'query': query,
        'results': cachedFoods,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error saving to user cache: $e');
      // Don't throw - cache save failures shouldn't block the flow
    }
  }

  /// Generate search terms for a food name
  /// This helps with partial matching (e.g., "mil" matches "milk")
  static List<String> _generateSearchTerms(String foodName) {
    final terms = <String>{};
    final normalized = foodName.toLowerCase();

    // Add the full name
    terms.add(normalized);

    // Add individual words
    final words = normalized.split(' ');
    terms.addAll(words);

    // Add prefixes for partial matching (minimum 3 characters)
    for (final word in words) {
      if (word.length >= 3) {
        for (int i = 3; i <= word.length; i++) {
          terms.add(word.substring(0, i));
        }
      }
    }

    return terms.toList();
  }

  /// Sanitize document ID to be Firestore-compatible
  static String _sanitizeDocId(String id) {
    return id
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Clear user's search cache
  static Future<void> clearUserCache() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection(_userSearchCacheCollection)
          .doc(userId)
          .collection('searches')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✓ User cache cleared');
    } catch (e) {
      print('Error clearing user cache: $e');
      rethrow;
    }
  }

  /// Get cached food by FDC ID
  static Future<FoodSearchResult?> getCachedFoodById(int fdcId) async {
    try {
      final doc = await _firestore
          .collection(_globalFoodsCollection)
          .doc(fdcId.toString())
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return CachedFood.fromJson(data).toFoodSearchResult();
    } catch (e) {
      print('Error getting cached food by ID: $e');
      return null;
    }
  }

  /// Preload common foods into global cache
  /// Call this once during app initialization or as needed
  static Future<void> preloadCommonFoods() async {
    final commonFoods = [
      'milk',
      'rice',
      'banana',
      'apple',
      'chicken breast',
      'egg',
      'bread',
      'cheese',
      'yogurt',
      'orange',
      'beef',
      'pork',
      'fish',
      'potato',
      'tomato',
      'carrot',
      'broccoli',
      'spinach',
      'lettuce',
      'oats',
    ];

    print('→ Preloading common foods...');

    for (final food in commonFoods) {
      try {
        // Check if already cached
        final existing = await _searchGlobalCache(food);
        if (existing.isNotEmpty) {
          print('  ✓ $food already cached');
          continue;
        }

        // Fetch and cache
        final response = await USDAApiService.searchFoods(
          query: food,
          pageSize: 5,
        );

        if (response.foods.isNotEmpty) {
          await _saveToGlobalCache(response.foods);
          print('  ✓ Cached $food (${response.foods.length} items)');
        }

        // Small delay to respect API rate limits
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('  ✗ Failed to cache $food: $e');
      }
    }

    print('✓ Common foods preload complete');
  }

  /// Get statistics about cache usage
  static Future<Map<String, int>> getCacheStats() async {
    final userId = _auth.currentUser?.uid;

    try {
      final globalSnapshot = await _firestore
          .collection(_globalFoodsCollection)
          .count()
          .get();

      int userCacheCount = 0;
      if (userId != null) {
        final userSnapshot = await _firestore
            .collection(_userSearchCacheCollection)
            .doc(userId)
            .collection('searches')
            .count()
            .get();
        userCacheCount = userSnapshot.count ?? 0;
      }

      return {
        'globalCache': globalSnapshot.count ?? 0,
        'userCache': userCacheCount,
      };
    } catch (e) {
      print('Error getting cache stats: $e');
      return {'globalCache': 0, 'userCache': 0};
    }
  }
}
