/// Example integration code for FitCheck Achievement System
///
/// This file contains practical examples showing how to integrate
/// achievement tracking throughout your app.
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/services/user_achievement_service.dart';

// ============================================================================
// EXAMPLE 1: Login Tracking in Main App
// ============================================================================

/// Call this when your app starts or user logs in
class AppInitializer {
  static Future<void> initializeOnAppLaunch() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Track daily login - this handles consecutive day logic automatically
        await UserAchievementService.trackDailyLogin();

        debugPrint('Daily login tracked for user: ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error initializing achievements: $e');
      // Don't block app startup on achievement errors
    }
  }
}

// ============================================================================
// EXAMPLE 2: Workout Completion Page
// ============================================================================

class WorkoutCompletionExample extends StatefulWidget {
  const WorkoutCompletionExample({super.key});

  @override
  State<WorkoutCompletionExample> createState() =>
      _WorkoutCompletionExampleState();
}

class _WorkoutCompletionExampleState extends State<WorkoutCompletionExample> {
  bool _isCompleting = false;

  Future<void> _completeWorkout({
    required String workoutName,
    required int caloriesBurned,
    required int durationMinutes,
  }) async {
    setState(() => _isCompleting = true);

    try {
      // 1. Save workout data to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .add({
        'name': workoutName,
        'caloriesBurned': caloriesBurned,
        'durationMinutes': durationMinutes,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Track for achievements - this increments stats and checks unlocks
      await UserAchievementService.trackWorkoutCompletion(caloriesBurned);

      // 3. Check for newly unlocked achievements
      final newlyUnlocked =
          await UserAchievementService.checkAndUnlockAchievements();

      if (mounted) {
        // 4. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout completed!'),
            backgroundColor: Colors.green,
          ),
        );

        // 5. Show achievement unlock notifications
        if (newlyUnlocked.isNotEmpty) {
          _showAchievementUnlockDialog(newlyUnlocked);
        }
      }
    } catch (e) {
      debugPrint('Error completing workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  void _showAchievementUnlockDialog(List<String> achievementIds) {
    for (final id in achievementIds) {
      final achievement = UserAchievementService.getAchievementWithMetadata(id);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              const SizedBox(width: 12),
              const Text('Achievement Unlocked!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                achievement['title'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(achievement['description'] as String),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Workout')),
      body: Center(
        child: ElevatedButton(
          onPressed: _isCompleting
              ? null
              : () => _completeWorkout(
                    workoutName: 'Morning Run',
                    caloriesBurned: 350,
                    durationMinutes: 30,
                  ),
          child: _isCompleting
              ? const CircularProgressIndicator()
              : const Text('Complete Workout'),
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 3: Photo Upload Integration
// ============================================================================

class PhotoUploadExample extends StatefulWidget {
  const PhotoUploadExample({super.key});

  @override
  State<PhotoUploadExample> createState() => _PhotoUploadExampleState();
}

class _PhotoUploadExampleState extends State<PhotoUploadExample> {
  bool _isUploading = false;

  Future<void> _uploadProgressPhoto(String imagePath) async {
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Upload photo to Firebase Storage (simplified)
      // In real app, use firebase_storage package
      final photoUrl = await _uploadToStorage(imagePath);

      // 2. Save photo metadata to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progress_photos')
          .add({
        'url': photoUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // 3. Track for achievements
      await UserAchievementService.trackPhotoUpload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Placeholder - implement with firebase_storage
  Future<String> _uploadToStorage(String imagePath) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate upload
    return 'https://example.com/photo.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Progress Photo')),
      body: Center(
        child: ElevatedButton(
          onPressed: _isUploading ? null : () => _uploadProgressPhoto('path'),
          child: _isUploading
              ? const CircularProgressIndicator()
              : const Text('Upload Photo'),
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 4: Meal Logging Integration
// ============================================================================

class MealLoggingExample extends StatefulWidget {
  const MealLoggingExample({super.key});

  @override
  State<MealLoggingExample> createState() => _MealLoggingExampleState();
}

class _MealLoggingExampleState extends State<MealLoggingExample> {
  Future<void> _logMeal({
    required String mealName,
    required String mealType, // breakfast, lunch, dinner, snack
    required int calories,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Save meal to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .add({
        'name': mealName,
        'type': mealType,
        'calories': calories,
        'loggedAt': FieldValue.serverTimestamp(),
      });

      // 2. Track for achievements (tracks unique days)
      await UserAchievementService.trackMealLogging();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$mealName logged successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error logging meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging meal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _logMeal(
                mealName: 'Chicken Salad',
                mealType: 'lunch',
                calories: 450,
              ),
              child: const Text('Log Lunch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 5: Challenge Completion Integration
// ============================================================================

class ChallengeCompletionExample extends StatefulWidget {
  final String challengeId;

  const ChallengeCompletionExample({
    super.key,
    required this.challengeId,
  });

  @override
  State<ChallengeCompletionExample> createState() =>
      _ChallengeCompletionExampleState();
}

class _ChallengeCompletionExampleState
    extends State<ChallengeCompletionExample> {
  Future<void> _completeChallenge() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Update challenge status in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .doc(widget.challengeId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Track for achievements
      await UserAchievementService.trackChallengeCompletion();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge completed!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or show celebration
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error completing challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge')),
      body: Center(
        child: ElevatedButton(
          onPressed: _completeChallenge,
          child: const Text('Mark Challenge Complete'),
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 6: Display Achievement Badge
// ============================================================================

class AchievementBadgeWidget extends StatefulWidget {
  const AchievementBadgeWidget({super.key});

  @override
  State<AchievementBadgeWidget> createState() => _AchievementBadgeWidgetState();
}

class _AchievementBadgeWidgetState extends State<AchievementBadgeWidget> {
  int _unlockedCount = 0;
  int _totalCount = 6;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await UserAchievementService.getAchievementCount();
      if (mounted) {
        setState(() {
          _unlockedCount = counts['unlocked'] ?? 0;
          _totalCount = counts['total'] ?? 6;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading achievement counts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(
            '$_unlockedCount/$_totalCount',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 7: View Current Stats
// ============================================================================

class StatsDisplayWidget extends StatefulWidget {
  const StatsDisplayWidget({super.key});

  @override
  State<StatsDisplayWidget> createState() => _StatsDisplayWidgetState();
}

class _StatsDisplayWidgetState extends State<StatsDisplayWidget> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await UserAchievementService.getUserStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Total Calories Burned',
              (_stats['total_calories_burned'] ?? 0).toString(),
              Icons.local_fire_department,
              Colors.deepOrange,
            ),
            _buildStatRow(
              'Login Streak',
              '${_stats['consecutive_login_days'] ?? 0} days',
              Icons.calendar_today,
              Colors.blue,
            ),
            _buildStatRow(
              'Total Workouts',
              (_stats['total_workouts'] ?? 0).toString(),
              Icons.fitness_center,
              Colors.pink,
            ),
            _buildStatRow(
              'Challenges Completed',
              (_stats['challenges_completed'] ?? 0).toString(),
              Icons.emoji_events,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 8: Testing/Debug Helper
// ============================================================================

class AchievementDebugHelper {
  /// Manually trigger achievement check (for testing)
  static Future<void> checkAchievementsNow() async {
    try {
      final newlyUnlocked =
          await UserAchievementService.checkAndUnlockAchievements();
      debugPrint('Achievement check complete. Newly unlocked: $newlyUnlocked');
    } catch (e) {
      debugPrint('Error checking achievements: $e');
    }
  }

  /// Print all current stats (for debugging)
  static Future<void> printCurrentStats() async {
    try {
      final stats = await UserAchievementService.getUserStats();
      debugPrint('=== CURRENT STATS ===');
      stats.forEach((key, value) {
        debugPrint('$key: $value');
      });
    } catch (e) {
      debugPrint('Error printing stats: $e');
    }
  }

  /// Print all achievements with progress (for debugging)
  static Future<void> printAchievements() async {
    try {
      final achievements =
          await UserAchievementService.getAllAchievementsWithDetails();
      debugPrint('=== ACHIEVEMENTS ===');
      for (final achievement in achievements) {
        final unlocked = achievement['unlocked'] ? 'UNLOCKED' : 'Locked';
        final progress = (achievement['progress'] * 100).toStringAsFixed(0);
        debugPrint(
            '${achievement['title']}: $unlocked ($progress%) - ${achievement['currentValue']}/${achievement['threshold']}');
      }
    } catch (e) {
      debugPrint('Error printing achievements: $e');
    }
  }

  /// Simulate workout completions (for testing - BE CAREFUL!)
  static Future<void> simulateWorkouts(int count, int caloriesEach) async {
    debugPrint('WARNING: Simulating $count workouts...');
    for (int i = 0; i < count; i++) {
      await UserAchievementService.trackWorkoutCompletion(caloriesEach);
      debugPrint('Simulated workout ${i + 1}/$count');
    }
    debugPrint('Simulation complete!');
  }
}

// ============================================================================
// EXAMPLE 9: Achievement Celebration Widget
// ============================================================================

class AchievementCelebrationOverlay extends StatelessWidget {
  final String achievementTitle;
  final String achievementDescription;
  final Color color;
  final VoidCallback onDismiss;

  const AchievementCelebrationOverlay({
    super.key,
    required this.achievementTitle,
    required this.achievementDescription,
    required this.color,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: color, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Achievement Unlocked!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                achievementTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievementDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
