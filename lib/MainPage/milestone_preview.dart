// lib/pages/milestone_preview_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/api_service.dart';
import 'video_preview_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/services/user_data_service.dart';

class DailyLogData {
  final DateTime date;
  final int totalCalories;
  final int calorieGoal;
  final int caloriesBurned;
  final Map<String, List<FoodEntry>> foodEntriesByMeal;
  final List<Workout> workouts;
  final String? notes;

  DailyLogData({
    required this.date,
    required this.totalCalories,
    required this.calorieGoal,
    required this.caloriesBurned,
    required this.foodEntriesByMeal,
    required this.workouts,
    this.notes,
  });

  String generateTextLog() {
    final StringBuffer buffer = StringBuffer();
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    buffer.writeln('📅 ${dateFormat.format(date)}\n');

    // Add notes if available
    if (notes != null && notes!.isNotEmpty) {
      buffer.writeln('📝 My Thoughts:');
      buffer.writeln(notes);
      buffer.writeln();
    }

    // Calorie Summary
    buffer.writeln('🎯 Calorie Summary:');
    buffer.writeln('• Goal: $calorieGoal cal');
    buffer.writeln('• Consumed: $totalCalories cal');
    buffer.writeln('• Burned: $caloriesBurned cal');
    final netCalories = totalCalories - caloriesBurned;
    buffer.writeln('• Net: $netCalories cal');
    buffer.writeln();

    // Food Logs
    bool hasFoodLogs = false;
    for (var entries in foodEntriesByMeal.values) {
      if (entries.isNotEmpty) {
        hasFoodLogs = true;
        break;
      }
    }

    if (hasFoodLogs) {
      buffer.writeln('🍽️ My Meals Today:\n');

      // Breakfast
      final breakfast = foodEntriesByMeal['Breakfast'] ?? [];
      if (breakfast.isNotEmpty) {
        buffer.writeln('☀️ Breakfast:');
        for (var entry in breakfast) {
          buffer.writeln('   • ${entry.foodName} - ${entry.totalCalories.round()} cal (${entry.servingSize.toStringAsFixed(0)}g)');
        }
        final breakfastTotal = breakfast.fold<int>(0, (sum, e) => sum + e.totalCalories.round());
        buffer.writeln('   Total: $breakfastTotal cal\n');
      }

      // Lunch
      final lunch = foodEntriesByMeal['Lunch'] ?? [];
      if (lunch.isNotEmpty) {
        buffer.writeln('🌤️ Lunch:');
        for (var entry in lunch) {
          buffer.writeln('   • ${entry.foodName} - ${entry.totalCalories.round()} cal (${entry.servingSize.toStringAsFixed(0)}g)');
        }
        final lunchTotal = lunch.fold<int>(0, (sum, e) => sum + e.totalCalories.round());
        buffer.writeln('   Total: $lunchTotal cal\n');
      }

      // Dinner
      final dinner = foodEntriesByMeal['Dinner'] ?? [];
      if (dinner.isNotEmpty) {
        buffer.writeln('🌙 Dinner:');
        for (var entry in dinner) {
          buffer.writeln('   • ${entry.foodName} - ${entry.totalCalories.round()} cal (${entry.servingSize.toStringAsFixed(0)}g)');
        }
        final dinnerTotal = dinner.fold<int>(0, (sum, e) => sum + e.totalCalories.round());
        buffer.writeln('   Total: $dinnerTotal cal\n');
      }

      // Snacks
      final snacks = foodEntriesByMeal['Snack'] ?? [];
      if (snacks.isNotEmpty) {
        buffer.writeln('🍿 Snacks:');
        for (var entry in snacks) {
          buffer.writeln('   • ${entry.foodName} - ${entry.totalCalories.round()} cal (${entry.servingSize.toStringAsFixed(0)}g)');
        }
        final snacksTotal = snacks.fold<int>(0, (sum, e) => sum + e.totalCalories.round());
        buffer.writeln('   Total: $snacksTotal cal\n');
      }
    } else {
      buffer.writeln('🍽️ No meals logged today.\n');
    }

    // Workouts
    if (workouts.isNotEmpty) {
      buffer.writeln('💪 My Workouts:\n');
      for (var workout in workouts) {
        if (workout.isCardio) {
          buffer.writeln('🏃 ${workout.exerciseName} (Cardio)');
          if (workout.durationMinutes != null) {
            buffer.writeln('   Duration: ${workout.durationMinutes} minutes');
          }
        } else {
          buffer.writeln('🏋️ ${workout.exerciseName} (Strength)');
          if (workout.sets != null && workout.reps != null) {
            buffer.writeln('   Sets: ${workout.sets} × ${workout.reps} reps');
          }
        }
        if (workout.notes != null && workout.notes!.isNotEmpty) {
          buffer.writeln('   Notes: ${workout.notes}');
        }
        buffer.writeln();
      }
    } else {
      buffer.writeln('💪 No workouts logged today.\n');
    }

    return buffer.toString().trim();
  }
}

class MilestonePreviewPage extends StatefulWidget {
  final List<Milestone> milestones;
  final int initialIndex;
  final VoidCallback? onMilestonesChanged;
  final String challengeId;


  const MilestonePreviewPage({
    super.key,
    required this.milestones,
    this.initialIndex = 0,
    this.onMilestonesChanged,
    required this.challengeId,
  });

  @override
  State<MilestonePreviewPage> createState() => _MilestonePreviewPageState();
}

class _MilestonePreviewPageState extends State<MilestonePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isSlideshow = false;
  bool _isExporting = false;
  Duration _slideshowInterval = const Duration(seconds: 2);

  // Cache the generated video URL
  String? _cachedVideoUrl;

  bool _isTextLogView = false;

  // Daily log data
  Map<String, DailyLogData> _dailyLogs = {};
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCachedVideoUrl(); // Load cached URL when page opens
  }

  // ======================
  // PERSISTENT VIDEO CACHE
  // ======================

  /// Generate a unique cache key based on challenge ID and milestone count
  String _getCacheKey() {
    return 'video_cache_${widget.challengeId}_${widget.milestones.length}';
  }

  /// Load cached video URL from SharedPreferences
  Future<void> _loadCachedVideoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final cachedUrl = prefs.getString(cacheKey);

      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        setState(() {
          _cachedVideoUrl = cachedUrl;
        });
      }
    } catch (e) {
      // Error loading cached video URL
    }
  }

  /// Save video URL to SharedPreferences
  Future<void> _saveCachedVideoUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      await prefs.setString(cacheKey, url);
    } catch (e) {
      // Error saving cached video URL
    }
  }

  /// Clear cached video URL from SharedPreferences
  Future<void> _clearCachedVideoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      await prefs.remove(cacheKey);
    } catch (e) {
      // Error clearing cached video URL
    }
  }


  Future<void> _loadDailyLogs() async {
    if (_isLoadingLogs || widget.milestones.isEmpty) return;

    setState(() => _isLoadingLogs = true);

    try {
      final Map<String, DailyLogData> logs = {};

      // Get calorie goal
      int goal = 2000;
      if (widget.challengeId.isNotEmpty) {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        goal = calculatedGoal;
      }

      for (var milestone in widget.milestones) {
        final date = milestone.date;

        // Load food logs
        final foodLogs = await FoodLogService.getFoodLogsForDate(
          date,
          challengeId: widget.challengeId,
        );

        int totalCalories = 0;
        Map<String, List<FoodEntry>> mealEntries = {
          'Breakfast': [],
          'Lunch': [],
          'Dinner': [],
          'Snack': [],
        };

        for (var log in foodLogs) {
          totalCalories += log.totalCalories.round();
          if (mealEntries.containsKey(log.mealType)) {
            mealEntries[log.mealType] = log.entries;
          }
        }

        // Load workouts
        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: widget.challengeId,
          date: date,
        );

        // Calculate calories burned
        int caloriesBurned = 0;
        if (workouts.isNotEmpty) {
          final userData = await UserDataService.loadUserData();
          final userWeight = userData?.weight?.toDouble() ?? 70.0;

          for (var workout in workouts) {
            caloriesBurned += workout.calculateCaloriesBurned(userWeight);
          }
        }

        logs[date.toString()] = DailyLogData(
          date: date,
          totalCalories: totalCalories,
          calorieGoal: goal,
          caloriesBurned: caloriesBurned,
          foodEntriesByMeal: mealEntries,
          workouts: workouts,
          notes: milestone.notes,
        );
      }

      setState(() {
        _dailyLogs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingLogs = false);
      _showSnackBar('Failed to load daily logs');
    }
  }

  @override
  void dispose() {
    _stopSlideshow();
    _pageController.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    if (_isSlideshow) return;
    setState(() => _isSlideshow = true);
    _runSlideshow();
  }

  void _runSlideshow() async {
    while (_isSlideshow && mounted) {
      await Future.delayed(_slideshowInterval);
      if (_isSlideshow && mounted && widget.milestones.isNotEmpty) {
        int nextIndex = (_currentIndex + 1) % widget.milestones.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _stopSlideshow() => setState(() => _isSlideshow = false);

  // ======================
  // EXPORT TO VIDEO (WITH VIDEO CACHING)
  // ======================
  Future<void> _exportMilestones() async {
    if (widget.milestones.isEmpty) {
      _showSnackBar('No milestones to export');
      return;
    }

    // CHECK IF VIDEO ALREADY EXISTS
    if (_cachedVideoUrl != null && _cachedVideoUrl!.isNotEmpty) {
      _showSnackBar('Opening existing video...');

      // Navigate directly to video preview
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorPage(
            videoUrl: _cachedVideoUrl!,
            videoTitle: 'Milestone Journey',
            milestones: widget.milestones,
            slideshowInterval: _slideshowInterval,
          ),
        ),
      );
      return;
    }

    // If no video exists, create a new one
    setState(() => _isExporting = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final List<File> filesToUpload = [];
      final List<String> notes = [];

      // Show loading dialog
      if (!mounted) return;
      _showLoadingDialog('Preparing images...');

      // Prepare files
      for (int i = 0; i < widget.milestones.length; i++) {
        final m = widget.milestones[i];
        notes.add(m.notes ?? '');

        // Priority 1: Use local imagePath if exists
        if (m.imagePath != null) {
          final f = File(m.imagePath!);
          if (await f.exists()) {
            filesToUpload.add(f);
            continue;
          }
        }

        // Priority 2: Download from imageUrl if exists
        if (m.imageUrl != null) {
          try {
            final resp = await http.get(
              Uri.parse(m.imageUrl!),
              headers: {'Accept': 'image/*'},
            ).timeout(const Duration(seconds: 15));

            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              final ext = _getImageExtensionFromUrl(m.imageUrl!) ?? '.jpg';
              final saved = File('${tempDir.path}/milestone_${i + 1}$ext');
              await saved.writeAsBytes(resp.bodyBytes);
              filesToUpload.add(saved);
              continue;
            }
          } catch (e) {
            // Error downloading image
          }
        }
      }

      if (filesToUpload.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('No image files available to upload');
        setState(() => _isExporting = false);
        return;
      }

      // Update loading message
      if (mounted) {
        Navigator.pop(context);
        _showLoadingDialog('Uploading ${filesToUpload.length} images...');
      }

      // Call API to generate video WITHOUT MUSIC
      final response = await ApiService.generateVideo(
        images: filesToUpload,
        notes: notes,
        musicFile: null,
        musicUrl: null,
        durationPerImage: _slideshowInterval.inSeconds,
      );

      // Extract render ID correctly from Shotstack response
      String? renderId;
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map) {
          final responseObj = data['response'];
          if (responseObj is Map && responseObj['id'] != null) {
            renderId = responseObj['id'].toString();
          }
        }
      }

      if (renderId == null || renderId.isEmpty) {
        if (mounted) Navigator.pop(context);
        throw Exception('Could not get render ID from response: $response');
      }

      // Update loading message
      if (mounted) {
        Navigator.pop(context);
        _showRenderProgressDialog(renderId);
      }

      // Poll for completion
      String? resultUrl;
      int maxAttempts = 90;
      int attempt = 0;

      while (attempt < maxAttempts && mounted) {
        await Future.delayed(const Duration(seconds: 3));
        attempt++;

        try {
          final statusResp = await ApiService.checkRenderStatus(renderId);

          if (statusResp['success'] == true) {
            final data = statusResp['data'];
            if (data is Map) {
              final responseObj = data['response'];
              if (responseObj is Map) {
                final status = responseObj['status']?.toString();
                final url = responseObj['url']?.toString();

                if (status == 'done' && url != null && url.isNotEmpty) {
                  resultUrl = url;
                  break;
                } else if (status == 'failed') {
                  final error = responseObj['error'] ?? 'Unknown error';
                  throw Exception('Render failed: $error');
                }
              }
            }
          }
        } catch (e) {
          if (attempt >= maxAttempts - 1) {
            throw Exception(
                'Failed to check render status after $attempt attempts: $e');
          }
        }
      }

      if (mounted) Navigator.pop(context);

      if (resultUrl != null && resultUrl.isNotEmpty) {
        // CACHE THE VIDEO URL (in memory and persistent storage)
        setState(() {
          _cachedVideoUrl = resultUrl;
          _isExporting = false;
        });

        // Save to SharedPreferences for persistence
        await _saveCachedVideoUrl(resultUrl);

        // Show video ready dialog with navigation option
        _showVideoReadyDialog(resultUrl);
      } else {
        _showSnackBar(
            'Render timeout after $attempt attempts. Video may still be processing.');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showSnackBar('Export failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ======================
  // LOADING DIALOGS
  // ======================
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FitCheckLoader(),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenderProgressDialog(String renderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Creating Video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FitCheckLoader(),
              const SizedBox(height: 20),
              const Text(
                'Please wait while we create your milestone video...',
                textAlign: TextAlign.center,
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // VIDEO READY DIALOG
  // ======================
  void _showVideoReadyDialog(String videoUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Elegant Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Success Icon with Animation Effect
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.2),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.secondary,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Video Successfully Created',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your milestone journey is ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Feature List
                    _buildFeatureItem(
                      icon: Icons.video_library_rounded,
                      title: 'Preview & Edit',
                      description: 'Review your video and customize it with background music',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: Icons.cloud_done_rounded,
                      title: 'Auto-Saved',
                      description: 'Your video is securely stored and accessible anytime',
                    ),

                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Later',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoEditorPage(
                                    videoUrl: videoUrl,
                                    videoTitle: 'Milestone Journey',
                                    milestones: widget.milestones,
                                    slideshowInterval: _slideshowInterval,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shadowColor: AppColors.secondary.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.play_circle_filled, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper widget for feature items
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _getImageExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      if (segments.isNotEmpty) {
        final fileName = segments.last.split('?').first;
        if (fileName.contains('.')) {
          return '.${fileName.split('.').last}';
        }
      }
    } catch (e) {
      // Error parsing URL extension
    }
    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSlideshowSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slideshow Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Slide Interval',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                _buildIntervalChip(const Duration(seconds: 1), '1s'),
                _buildIntervalChip(const Duration(seconds: 2), '2s'),
                _buildIntervalChip(const Duration(seconds: 3), '3s'),
                _buildIntervalChip(const Duration(seconds: 5), '5s'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startSlideshow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start Slideshow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(Duration duration, String label) {
    bool isSelected = _slideshowInterval == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _slideshowInterval = duration;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final milestones = widget.milestones;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${_currentIndex + 1} of ${milestones.length} · "
              "${DateFormat("MMM d, yyyy").format(milestones[_currentIndex].date)}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // 👇 NEW: Toggle view button
          IconButton(
            icon: Icon(
              _isTextLogView ? Icons.image : Icons.notes,
              color: Colors.white,
            ),
            onPressed: () async {
              if (!_isTextLogView && _dailyLogs.isEmpty) {
                // Load logs when switching to text view for the first time
                await _loadDailyLogs();
              }
              setState(() {
                _isTextLogView = !_isTextLogView;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isSlideshow ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _isTextLogView
                ? null
                : (_isSlideshow ? _stopSlideshow : () => _showSlideshowSettings()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_image',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Change Image'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_image',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Image', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                enabled: !_isExporting,
                child: Row(
                  children: [
                    _isExporting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Icon(
                      _cachedVideoUrl != null ? Icons.video_library : Icons.video_call,
                      size: 20,
                      color: _cachedVideoUrl != null ? Colors.green : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isExporting
                          ? 'Exporting...'
                          : _cachedVideoUrl != null
                          ? 'Open Video'
                          : 'Export to Video',
                      style: TextStyle(
                        color: _cachedVideoUrl != null ? Colors.green : null,
                        fontWeight: _cachedVideoUrl != null ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isTextLogView ? _buildTextLogView() : Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: milestones.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return Stack(
                  children: [
                    Center(
                      child: milestone.imageUrl != null
                          ? Image.network(
                        milestone.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress
                                  .expectedTotalBytes !=
                                  null
                                  ? loadingProgress
                                  .cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.white54,
                          );
                        },
                      )
                          : milestone.imagePath != null
                          ? Image.file(
                        File(milestone.imagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.white54,
                          );
                        },
                      )
                          : const Icon(Icons.image_not_supported,
                          size: 100, color: Colors.white54),
                    ),
                    if (_isSlideshow)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.slideshow,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_slideshowInterval.inSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (milestone.notes != null && milestone.notes!.isNotEmpty)
                      Positioned(
                        bottom: 110,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            milestone.notes!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return GestureDetector(
                  onTap: () {
                    _pageController.jumpToPage(index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(milestone),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    if (_isExporting && action != 'export') return;

    switch (action) {
      case 'change_image':
        _changeCurrentImage();
        break;
      case 'delete_image':
        _deleteCurrentImage();
        break;
      case 'export':
        _exportMilestones();
        break;
    }
  }

  void _changeCurrentImage() async {
    if (widget.milestones.isEmpty) return;
    final milestone = widget.milestones[_currentIndex];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () =>
                      _pickImageForChange(ImageSource.camera, milestone),
                ),
                _buildImageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () =>
                      _pickImageForChange(ImageSource.gallery, milestone),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  void _pickImageForChange(ImageSource source, Milestone milestone) async {
    Navigator.pop(context);

    try {
      // ⭐ ADD PERMISSION HANDLING
      if (source == ImageSource.camera) {
        var status = await Permission.camera.request();
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Camera permission denied")),
          );
          return;
        }
      } else if (source == ImageSource.gallery) {
        // Request photo permission for gallery
        PermissionStatus status;

        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;

          if (androidInfo.version.sdkInt >= 33) {
            // Android 13+ - Use photos permission
            status = await Permission.photos.request();
          } else {
            // Android 12 and below - Use storage permission
            status = await Permission.storage.request();
          }

          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Photos permission is required to select images")),
            );
            return;
          }
        }
      }

      // Now pick the image after permission is granted
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        setState(() => _isExporting = true);
        final updatedMilestone = milestone.copyWith(
          imagePath: pickedFile.path,
          updatedAt: DateTime.now(),
        );

        final success = await MilestoneService.updateMilestone(
          updatedMilestone,
          challengeId: widget.challengeId,
          newImageFile: File(pickedFile.path),
        );

        if (success) {
          setState(() {
            widget.milestones[_currentIndex] = updatedMilestone;
            // CLEAR CACHED VIDEO since images changed
            _cachedVideoUrl = null;
          });
          // Clear persistent cache
          await _clearCachedVideoUrl();

          widget.onMilestonesChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Image updated successfully! Video cache cleared.'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to update image. Please try again.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _deleteCurrentImage() {
    if (widget.milestones.isEmpty) return;
    final milestone = widget.milestones[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
            'Are you sure you want to delete this milestone image? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => _confirmDelete(milestone),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Milestone milestone) async {
    Navigator.pop(context);
    try {
      setState(() => _isExporting = true);
      final success = await MilestoneService.deleteMilestone(milestone.id,
          challengeId: widget.challengeId);
      if (success) {
        setState(() {
          final index = _currentIndex;
          widget.milestones.removeAt(index);
          // CLEAR CACHED VIDEO since images changed
          _cachedVideoUrl = null;

          if (widget.milestones.isEmpty) {
            Navigator.pop(context);
            return;
          } else if (index >= widget.milestones.length) {
            _currentIndex = widget.milestones.length - 1;
            _pageController.animateToPage(_currentIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        });
        // Clear persistent cache
        await _clearCachedVideoUrl();

        widget.onMilestonesChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image deleted successfully! Video cache cleared.'),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete image. Please try again.'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildImageWidget(Milestone milestone) {
    if (milestone.imageUrl != null) {
      return Image.network(milestone.imageUrl!,
          width: 60, height: 80, fit: BoxFit.cover);
    } else if (milestone.imagePath != null) {
      return Image.file(File(milestone.imagePath!),
          width: 60, height: 80, fit: BoxFit.cover);
    } else {
      return Container(
          width: 60,
          height: 80,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported));
    }
  }
  Widget _buildTextLogView() {
    if (_isLoadingLogs) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FitCheckLoader(),
            SizedBox(height: 20),
            Text(
              'Loading daily logs...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final milestones = widget.milestones;

    return PageView.builder(
      controller: _pageController,
      itemCount: milestones.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final milestone = milestones[index];
        final logData = _dailyLogs[milestone.date.toString()];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(milestone.date),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM d, yyyy').format(milestone.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Text log content
                if (logData != null) ...[
                  SelectableText(
                    logData.generateTextLog(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No logs available for this day',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: logData != null
                        ? () => _shareTextLog(logData.generateTextLog())
                        : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Log'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareTextLog(String logText) async {
    try {
      await Share.share(
        logText,
        subject: 'My Fitness Log - ${DateFormat('MMM d, yyyy').format(widget.milestones[_currentIndex].date)}',
      );
    } catch (e) {
      _showSnackBar('Failed to share log');
    }
  }
}