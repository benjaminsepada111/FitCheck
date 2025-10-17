import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing user-specific achievements in Firestore
///
/// Each user has their own stats and achievements stored under their Firebase UID.
/// Achievements are automatically checked and unlocked when users meet conditions.
class UserAchievementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Achievement definitions with unlock conditions
  static const Map<String, Map<String, dynamic>> achievementDefinitions = {
    'challenge_conqueror': {
      'title': 'Challenge Conqueror',
      'description': 'Complete your first challenge',
      'icon': 'flag',
      'color': 0xFF4CAF50, // Green
      'condition': 'challenges_completed',
      'threshold': 1,
    },
    'calorie_tracker': {
      'title': 'Calorie Tracker',
      'description': 'Consume 10000 calories total',
      'icon': 'local_fire_department',
      'color': 0xFFFF5722, // Deep Orange
      'condition': 'total_calories_consumed',
      'threshold': 10000,
    },
    'steadfast': {
      'title': 'Steadfast',
      'description': 'Log in for 7 days',
      'icon': 'calendar_today',
      'color': 0xFF2196F3, // Blue
      'condition': 'total_login_days',
      'threshold': 7,
    },
    'perseverance': {
      'title': 'Perseverance',
      'description': 'Upload progress photos for 7 days',
      'icon': 'photo_camera',
      'color': 0xFF9C27B0, // Purple
      'condition': 'photo_upload_days',
      'threshold': 7,
    },
    'discipline': {
      'title': 'Discipline',
      'description': 'Log meals for 30 days',
      'icon': 'restaurant',
      'color': 0xFFFF9800, // Orange
      'condition': 'meal_logging_days',
      'threshold': 30,
    },
    'workout_warrior': {
      'title': 'Workout Warrior',
      'description': 'Complete 50 workouts',
      'icon': 'fitness_center',
      'color': 0xFFE91E63, // Pink
      'condition': 'total_workouts',
      'threshold': 50,
    },
  };

  /// Get or initialize user stats document
  static Future<DocumentReference> _getUserStatsRef() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final statsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stats')
        .doc('user_stats');

    // Initialize stats if they don't exist
    final statsDoc = await statsRef.get();
    if (!statsDoc.exists) {
      await statsRef.set({
        'total_calories_consumed': 0,
        'total_login_days': 0,
        'photo_upload_days': 0,
        'meal_logging_days': 0,
        'total_workouts': 0,
        'challenges_completed': 0,
        'last_login_date': null,
        'login_dates': [],
        'photo_upload_dates': [],
        'meal_logging_dates': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    return statsRef;
  }

  /// Get user stats
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final statsRef = await _getUserStatsRef();
      final statsDoc = await statsRef.get();
      return statsDoc.data() as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {};
    }
  }

  /// Update user stats
  static Future<void> updateStats(Map<String, dynamic> updates) async {
    try {
      final statsRef = await _getUserStatsRef();
      updates['updated_at'] = FieldValue.serverTimestamp();
      await statsRef.update(updates);

      // Check achievements after stats update
      await checkAndUnlockAchievements();
    } catch (e) {
      debugPrint('Error updating stats: $e');
      rethrow;
    }
  }

  /// Increment a stat value
  static Future<void> incrementStat(String statKey, int amount) async {
    try {
      final statsRef = await _getUserStatsRef();
      await statsRef.update({
        statKey: FieldValue.increment(amount),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Check achievements after stats update
      await checkAndUnlockAchievements();
    } catch (e) {
      debugPrint('Error incrementing stat: $e');
      rethrow;
    }
  }

  /// Track daily login
  static Future<void> trackDailyLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final statsRef = await _getUserStatsRef();
      final statsDoc = await statsRef.get();
      final stats = statsDoc.data() as Map<String, dynamic>? ?? {};

      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get existing login dates
      final loginDates = List<String>.from(stats['login_dates'] ?? []);

      // Check if already logged in today
      if (loginDates.contains(todayKey)) {
        return; // Already logged in today
      }

      // Add today's date
      loginDates.add(todayKey);

      await statsRef.update({
        'login_dates': loginDates,
        'total_login_days': loginDates.length,
        'last_login_date': todayKey,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Check achievements
      await checkAndUnlockAchievements();
    } catch (e) {
      debugPrint('Error tracking daily login: $e');
    }
  }

  /// Track photo upload
  static Future<void> trackPhotoUpload() async {
    try {
      final statsRef = await _getUserStatsRef();
      final statsDoc = await statsRef.get();
      final stats = statsDoc.data() as Map<String, dynamic>? ?? {};

      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final photoDates = List<String>.from(stats['photo_upload_dates'] ?? []);

      if (!photoDates.contains(todayKey)) {
        photoDates.add(todayKey);
        await statsRef.update({
          'photo_upload_dates': photoDates,
          'photo_upload_days': photoDates.length,
          'updated_at': FieldValue.serverTimestamp(),
        });

        await checkAndUnlockAchievements();
      }
    } catch (e) {
      debugPrint('Error tracking photo upload: $e');
    }
  }

  /// Track meal logging with calories
  static Future<void> trackMealLogging({int calories = 0}) async {
    try {
      debugPrint('🍽️ Tracking meal: $calories calories');
      final statsRef = await _getUserStatsRef();
      final statsDoc = await statsRef.get();
      final stats = statsDoc.data() as Map<String, dynamic>? ?? {};

      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final mealDates = List<String>.from(stats['meal_logging_dates'] ?? []);

      Map<String, dynamic> updates = {
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Track calories consumed
      if (calories > 0) {
        updates['total_calories_consumed'] = FieldValue.increment(calories);
        debugPrint('📊 Adding $calories to total_calories_consumed');
      } else {
        debugPrint('⚠️ No calories to track (calories = $calories)');
      }

      // Track meal logging day
      if (!mealDates.contains(todayKey)) {
        mealDates.add(todayKey);
        updates['meal_logging_dates'] = mealDates;
        updates['meal_logging_days'] = mealDates.length;
        debugPrint('📅 New meal logging day: $todayKey');
      }

      debugPrint('💾 Updating stats with: $updates');
      await statsRef.update(updates);
      debugPrint('✅ Stats updated successfully');
      await checkAndUnlockAchievements();
    } catch (e) {
      debugPrint('❌ Error tracking meal logging: $e');
    }
  }

  /// Track workout completion
  static Future<void> trackWorkoutCompletion() async {
    try {
      final statsRef = await _getUserStatsRef();
      await statsRef.update({
        'total_workouts': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await checkAndUnlockAchievements();
    } catch (e) {
      debugPrint('Error tracking workout completion: $e');
    }
  }

  /// Track challenge completion
  static Future<void> trackChallengeCompletion() async {
    try {
      await incrementStat('challenges_completed', 1);
    } catch (e) {
      debugPrint('Error tracking challenge completion: $e');
    }
  }


  /// Get user achievements
  static Future<Map<String, UserAchievement>> getUserAchievements() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final achievementsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .get();

      final achievements = <String, UserAchievement>{};

      for (var doc in achievementsSnapshot.docs) {
        achievements[doc.id] = UserAchievement.fromFirestore(doc);
      }

      // Add any missing achievements as locked
      for (var achievementId in achievementDefinitions.keys) {
        if (!achievements.containsKey(achievementId)) {
          achievements[achievementId] = UserAchievement(
            id: achievementId,
            unlocked: false,
            progress: 0.0,
            unlockedAt: null,
          );
        }
      }

      return achievements;
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
      return {};
    }
  }

  /// Check and unlock achievements based on current stats
  static Future<List<String>> checkAndUnlockAchievements() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final stats = await getUserStats();
      final achievements = await getUserAchievements();
      final newlyUnlocked = <String>[];

      for (var entry in achievementDefinitions.entries) {
        final achievementId = entry.key;
        final definition = entry.value;
        final currentAchievement = achievements[achievementId];

        // Skip if already unlocked
        if (currentAchievement?.unlocked == true) continue;

        // Check condition
        final condition = definition['condition'] as String;
        final threshold = definition['threshold'] as int;
        final currentValue = (stats[condition] ?? 0) as int;
        final progress = (currentValue / threshold).clamp(0.0, 1.0);

        // Update progress
        await _updateAchievementProgress(achievementId, progress);

        // Unlock if threshold met
        if (currentValue >= threshold) {
          await _unlockAchievement(achievementId);
          newlyUnlocked.add(achievementId);
          debugPrint('Achievement unlocked: ${definition['title']}');
        }
      }

      return newlyUnlocked;
    } catch (e) {
      debugPrint('Error checking achievements: $e');
      return [];
    }
  }

  /// Update achievement progress
  static Future<void> _updateAchievementProgress(
    String achievementId,
    double progress,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final achievementRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc(achievementId);

      await achievementRef.set({
        'progress': progress,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating achievement progress: $e');
    }
  }

  /// Unlock an achievement
  static Future<void> _unlockAchievement(String achievementId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final achievementRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc(achievementId);

      await achievementRef.set({
        'unlocked': true,
        'progress': 1.0,
        'unlocked_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  /// Get achievement with metadata
  static Map<String, dynamic> getAchievementWithMetadata(String achievementId) {
    final definition = achievementDefinitions[achievementId];
    if (definition == null) {
      return {
        'title': achievementId,
        'description': 'Unknown achievement',
        'icon': 'star',
        'color': 0xFF9E9E9E,
      };
    }
    return definition;
  }

  /// Get all achievements with full details
  static Future<List<Map<String, dynamic>>> getAllAchievementsWithDetails() async {
    try {
      final userAchievements = await getUserAchievements();
      final stats = await getUserStats();

      return achievementDefinitions.entries.map((entry) {
        final achievementId = entry.key;
        final definition = entry.value;
        final userAchievement = userAchievements[achievementId];

        // Calculate current progress
        final condition = definition['condition'] as String;
        final threshold = definition['threshold'] as int;
        final currentValue = (stats[condition] ?? 0) as int;
        final progress = userAchievement?.progress ??
                        (currentValue / threshold).clamp(0.0, 1.0);

        return {
          'id': achievementId,
          'title': definition['title'],
          'description': definition['description'],
          'icon': definition['icon'],
          'color': definition['color'],
          'unlocked': userAchievement?.unlocked ?? false,
          'progress': progress,
          'currentValue': currentValue,
          'threshold': threshold,
          'unlockedAt': userAchievement?.unlockedAt,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting all achievements: $e');
      return [];
    }
  }

  /// Get recently unlocked achievements (last 7 days)
  static Future<List<Map<String, dynamic>>> getRecentlyUnlockedAchievements() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final achievementsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .where('unlocked', isEqualTo: true)
          .where('unlocked_at', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      return achievementsSnapshot.docs.map((doc) {
        final data = doc.data();
        final definition = achievementDefinitions[doc.id] ?? {};
        return {
          'id': doc.id,
          'title': definition['title'] ?? 'Achievement',
          'description': definition['description'] ?? '',
          'icon': definition['icon'] ?? 'star',
          'color': definition['color'] ?? 0xFF9E9E9E,
          'unlockedAt': (data['unlocked_at'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting recently unlocked achievements: $e');
      return [];
    }
  }

  /// Get achievement count
  static Future<Map<String, int>> getAchievementCount() async {
    try {
      final achievements = await getUserAchievements();
      final unlockedCount = achievements.values.where((a) => a.unlocked).length;
      final totalCount = achievementDefinitions.length;

      return {
        'unlocked': unlockedCount,
        'total': totalCount,
      };
    } catch (e) {
      debugPrint('Error getting achievement count: $e');
      return {'unlocked': 0, 'total': achievementDefinitions.length};
    }
  }
}

/// User achievement model
class UserAchievement {
  final String id;
  final bool unlocked;
  final double progress;
  final DateTime? unlockedAt;

  UserAchievement({
    required this.id,
    required this.unlocked,
    required this.progress,
    this.unlockedAt,
  });

  factory UserAchievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserAchievement(
      id: doc.id,
      unlocked: data['unlocked'] ?? false,
      progress: (data['progress'] ?? 0.0).toDouble(),
      unlockedAt: (data['unlocked_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unlocked': unlocked,
      'progress': progress,
      'unlocked_at': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
    };
  }
}
