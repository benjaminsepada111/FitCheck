// widgets/challenge_completion_dialog.dart
import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
import 'package:confetti/confetti.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/api_service.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:capstone_project/MainPage/video_preview_page.dart';

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

    buffer.writeln('${DateFormat('MMMM d, yyyy').format(date)}\n');

    // Add notes if available
    if (notes != null && notes!.isNotEmpty) {
      buffer.writeln('${notes}\n');
    }

    // Food section
    bool hasFoodLogs = false;
    List<String> allFoodItems = [];

    for (var entries in foodEntriesByMeal.values) {
      if (entries.isNotEmpty) {
        hasFoodLogs = true;
        for (var entry in entries) {
          allFoodItems.add('${entry.foodName} (${entry.totalCalories.round()} cal)');
        }
      }
    }

    if (hasFoodLogs) {
      buffer.writeln('I ate:');
      for (var item in allFoodItems) {
        buffer.writeln('  • $item');
      }
      buffer.writeln();
    } else {
      buffer.writeln('No meals logged today\n');
    }

    // Workout section
    if (workouts.isNotEmpty) {
      buffer.writeln('I worked out:');

      for (var workout in workouts) {
        if (workout.isCardio) {
          if (workout.durationMinutes != null) {
            buffer.writeln('  • ${workout.exerciseName} (${workout.durationMinutes} min)');
          } else {
            buffer.writeln('  • ${workout.exerciseName}');
          }
        } else {
          if (workout.sets != null && workout.reps != null) {
            buffer.writeln('  • ${workout.exerciseName} (${workout.sets}×${workout.reps})');
          } else {
            buffer.writeln('  • ${workout.exerciseName}');
          }
        }
      }
      buffer.writeln();
    } else {
      buffer.writeln('No workouts logged today\n');
    }

    // Calorie summary
    buffer.writeln('Consumed: $totalCalories cal');

    if (caloriesBurned > 0) {
      buffer.writeln('Burned: $caloriesBurned cal');
      final netCalories = totalCalories - caloriesBurned;
      buffer.writeln('Net: $netCalories cal');
    }

    return buffer.toString().trim();
  }
}



class ChallengeCompletionDialog extends StatefulWidget {
  final Challenge challenge;
  final VoidCallback onCreateNewChallenge;
  final VoidCallback onDismiss;

  const ChallengeCompletionDialog({
    super.key,
    required this.challenge,
    required this.onCreateNewChallenge,
    required this.onDismiss,
  });

  @override
  State<ChallengeCompletionDialog> createState() =>
      _ChallengeCompletionDialogState();
}

class _ChallengeCompletionDialogState extends State<ChallengeCompletionDialog>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Video generation state
  bool _isExporting = false;
  String? _cachedVideoUrl;
  List<String>? _cachedTextLogs;
  List<Milestone> _milestones = [];
  Map<String, DailyLogData> _dailyLogs = {};
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start animations
    _animationController.forward();
    _confettiController.play();

    // Load milestones and cached video
    _loadMilestones();
  }

  // ======================
  // VIDEO GENERATION - CACHE MANAGEMENT
  // ======================

  String _getImageHash() {
    final imageData = _milestones.map((m) {
      return '${m.imageUrl ?? m.imagePath ?? ''}';
    }).join('|');

    int hash = 0;
    for (int i = 0; i < imageData.length; i++) {
      hash = (hash + imageData.codeUnitAt(i)) % 1000000;
    }

    return hash.toString();
  }

  String _getCacheKey() {
    final challengeId = widget.challenge.id;
    final imageHash = _getImageHash();
    return 'video_cache_${challengeId}_${_milestones.length}_$imageHash';
  }

  String _getTextLogsCacheKey() {
    final challengeId = widget.challenge.id;
    return 'text_logs_cache_${challengeId}_${_milestones.length}';
  }

  Future<void> _loadCachedVideoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final textLogsCacheKey = _getTextLogsCacheKey();

      final cachedUrl = prefs.getString(cacheKey);
      final cachedLogsJson = prefs.getString(textLogsCacheKey);

      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        setState(() {
          _cachedVideoUrl = cachedUrl;

          if (cachedLogsJson != null) {
            try {
              _cachedTextLogs = List<String>.from(jsonDecode(cachedLogsJson));
            } catch (e) {
              print('⚠️ Failed to decode cached text logs: $e');
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error loading cached data: $e');
    }
  }

  Future<void> _saveCachedVideoUrl(String url, List<String> textLogs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final textLogsCacheKey = _getTextLogsCacheKey();

      await prefs.setString(cacheKey, url);
      await prefs.setString(textLogsCacheKey, jsonEncode(textLogs));

      print('✅ Cached video URL and text logs');
    } catch (e) {
      print('❌ Error saving cached data: $e');
    }
  }

  // ======================
  // MILESTONE & DAILY LOGS LOADING
  // ======================

  Future<void> _loadMilestones() async {
    try {
      final challengeId = widget.challenge.id;

      final allMilestones = await MilestoneService.getAllMilestones(
        challengeId: challengeId,
        limit: 100,
      );

      final milestonesWithImages = allMilestones.where((m) {
        return (m.imageUrl != null && m.imageUrl!.isNotEmpty) ||
            (m.imagePath != null && m.imagePath!.isNotEmpty);
      }).toList();

      milestonesWithImages.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _milestones = milestonesWithImages;
      });

      if (milestonesWithImages.isNotEmpty) {
        await _loadCachedVideoUrl();
      }
    } catch (e) {
      print('❌ Error loading milestones: $e');
    }
  }

  Future<void> _loadDailyLogs() async {
    if (_isLoadingLogs || _milestones.isEmpty) return;

    setState(() => _isLoadingLogs = true);

    try {
      final Map<String, DailyLogData> logs = {};
      final challengeId = widget.challenge.id;
      int goal = widget.challenge.dailyCalorieGoal;

      for (var milestone in _milestones) {
        final date = milestone.date;

        final foodLogs = await FoodLogService.getFoodLogsForDate(
          date,
          challengeId: challengeId,
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

        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: challengeId,
          date: date,
        );

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

  // ======================
  // VIDEO GENERATION - MAIN LOGIC
  // ======================

  Future<void> _generateMilestoneVideo() async {
    if (_milestones.isEmpty) {
      _showSnackBar('No milestone photos available. Add photos to your milestones first!');
      return;
    }

    // CHECK IF VIDEO ALREADY EXISTS
    if (_cachedVideoUrl != null && _cachedVideoUrl!.isNotEmpty) {
      _showSnackBar('Opening existing video...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorPage(
            videoUrl: _cachedVideoUrl!,
            videoTitle: 'Milestone Journey',
            milestones: _milestones,
            slideshowInterval: const Duration(seconds: 2),
            textLogs: _cachedTextLogs,
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
      final List<String> textLogs = [];

      // Show loading dialog
      if (!mounted) return;
      _showLoadingDialog('Loading daily logs and preparing video...');

      await _loadDailyLogs();

      if (!mounted) return;
      Navigator.pop(context);
      _showLoadingDialog('Preparing ${_milestones.length} images with text overlays...');

      for (int i = 0; i < _milestones.length; i++) {
        final m = _milestones[i];
        File? imageFile;
        bool imageAdded = false;

        if (m.imagePath != null) {
          final f = File(m.imagePath!);
          if (await f.exists()) {
            imageFile = f;
            imageAdded = true;
          }
        }

        if (!imageAdded && m.imageUrl != null) {
          try {
            final resp = await http.get(
              Uri.parse(m.imageUrl!),
              headers: {'Accept': 'image/*'},
            ).timeout(const Duration(seconds: 15));

            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              final ext = _getImageExtensionFromUrl(m.imageUrl!) ?? '.jpg';
              final saved = File('${tempDir.path}/milestone_${i + 1}$ext');
              await saved.writeAsBytes(resp.bodyBytes);
              imageFile = saved;
              imageAdded = true;
            }
          } catch (e) {
            print('❌ Error downloading image ${i+1}: $e');
          }
        }

        if (imageAdded && imageFile != null) {
          final logData = _dailyLogs[m.date.toString()];
          String fullTextLog = '';

          if (logData != null) {
            fullTextLog = logData.generateTextLog();
          } else if (m.notes != null && m.notes!.isNotEmpty) {
            final dateStr = DateFormat('MMM d, yyyy').format(m.date);
            fullTextLog = '$dateStr\n\n${m.notes!}';
          } else {
            final dateStr = DateFormat('MMMM d, yyyy').format(m.date);
            fullTextLog = '$dateStr\n\nNo activity logged for this day';
          }

          filesToUpload.add(imageFile);
          textLogs.add(fullTextLog);
        }
      }

      if (filesToUpload.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('No image files available to upload');
        setState(() => _isExporting = false);
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        _showLoadingDialog('Uploading ${filesToUpload.length} images with text overlays...');
      }

      final response = await ApiService.generateVideo(
        images: filesToUpload,
        notes: textLogs,
        musicFile: null,
        musicUrl: null,
        durationPerImage: 2,
      );

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
        throw Exception('Could not get render ID from response');
      }

      if (mounted) {
        Navigator.pop(context);
        _showRenderProgressDialog(renderId);
      }

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
            throw Exception('Failed to check render status: $e');
          }
        }
      }

      if (mounted) Navigator.pop(context);

      if (resultUrl != null && resultUrl.isNotEmpty) {
        setState(() {
          _cachedVideoUrl = resultUrl;
          _cachedTextLogs = textLogs;
          _isExporting = false;
        });

        await _saveCachedVideoUrl(resultUrl, textLogs);

        _showVideoReadyDialog(resultUrl, textLogs);
      } else {
        _showSnackBar('Render timeout. Video may still be processing.');
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
  // HELPER METHODS
  // ======================

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
            children: const [
              FitCheckLoader(),
              SizedBox(height: 20),
              Text(
                'Please wait while we create your milestone video...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoReadyDialog(String videoUrl, List<String> textLogs) {
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
                                    milestones: _milestones,
                                    slideshowInterval: const Duration(seconds: 2),
                                    textLogs: textLogs,
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

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: r.size(20),
        vertical: r.size(40),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.secondary,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),

          // Dialog content - Wrapped in SingleChildScrollView
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.85, // Max 85% of screen height
                ),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(r.size(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient Header with Trophy
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: r.size(32),
                            horizontal: r.size(20),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.secondary,
                                AppColors.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(r.size(24)),
                              topRight: Radius.circular(r.size(24)),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Trophy Icon with white background
                              Container(
                                width: r.size(80),
                                height: r.size(80),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.emoji_events,
                                  size: r.size(50),
                                  color: Colors.orange.shade600,
                                ),
                              ),

                              ResponsiveGap.vertical(12),

                              // Title
                              Text(
                                'Challenge Complete!',
                                style: TextStyle(
                                  fontSize: r.font(24, min: 20, max: 28),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              ResponsiveGap.vertical(2),

                            ],
                          ),
                        ),

                        // Content section
                        Padding(
                          padding: EdgeInsets.all(r.size(20)),
                          child: Column(
                            children: [
                              // Challenge Info Card
                              Container(
                                padding: EdgeInsets.all(r.size(16)),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(r.size(16)),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Challenge label
                                    Text(
                                      'Challenge',
                                      style: TextStyle(
                                        fontSize: r.font(11, min: 10, max: 12),
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    ResponsiveGap.vertical(8),

                                    // Challenge Name
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(r.size(6)),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(r.size(6)),
                                          ),

                                        ),
                                        ResponsiveGap.horizontal(8),
                                        Flexible(
                                          child: Text(
                                            widget.challenge.title,
                                            style: TextStyle(
                                              fontSize: r.font(15, min: 13, max: 17),
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    ResponsiveGap.vertical(12),

                                    // Divider
                                    Container(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),

                                    ResponsiveGap.vertical(12),

                                    // Duration - Column layout for small screens
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: r.size(14),
                                              color: Colors.grey.shade600,
                                            ),
                                            ResponsiveGap.horizontal(6),
                                            Text(
                                              '${widget.challenge.durationInDays} days',
                                              style: TextStyle(
                                                fontSize: r.font(13, min: 12, max: 14),
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        ResponsiveGap.vertical(4),
                                        Text(
                                          widget.challenge.dateRangeString,
                                          style: TextStyle(
                                            fontSize: r.font(11, min: 10, max: 12),
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              ResponsiveGap.vertical(16),

                              // Milestone Video Ready - Mint green theme with Generate Button
                              Container(
                                padding: EdgeInsets.all(r.size(14)),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(r.size(14)),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(r.size(10)),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(r.size(10)),
                                          ),
                                          child: Icon(
                                            Icons.video_library,
                                            size: r.size(20),
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        ResponsiveGap.horizontal(12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _cachedVideoUrl != null
                                                    ? 'Your Milestone Video is Ready!'
                                                    : 'Create Your Milestone Video',
                                                style: TextStyle(
                                                  fontSize: r.font(13, min: 12, max: 14),
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.green.shade900,
                                                ),
                                              ),
                                              ResponsiveGap.vertical(2),
                                              Text(
                                                _cachedVideoUrl != null
                                                    ? 'View your journey video anytime'
                                                    : _milestones.isEmpty
                                                    ? 'Add milestone photos to create a video'
                                                    : 'Generate a video of your ${_milestones.length} milestone${_milestones.length == 1 ? "" : "s"}',
                                                style: TextStyle(
                                                  fontSize: r.font(11, min: 10, max: 12),
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    ResponsiveGap.vertical(12),
                                    // Generate Video Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: r.size(44),
                                      child: ElevatedButton(
                                        onPressed: _isExporting ? null : _generateMilestoneVideo,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          disabledBackgroundColor: Colors.grey.shade400,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(r.size(12)),
                                          ),
                                        ),
                                        child: _isExporting
                                            ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: r.size(16),
                                              height: r.size(16),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            ResponsiveGap.horizontal(8),
                                            Text(
                                              'Generating...',
                                              style: TextStyle(
                                                fontSize: r.font(14, min: 13, max: 15),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        )
                                            : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.video_call,
                                              size: r.size(18),
                                            ),
                                            ResponsiveGap.horizontal(8),
                                            Text(
                                              _cachedVideoUrl != null ? 'Open Video' : 'Generate Video',
                                              style: TextStyle(
                                                fontSize: r.font(14, min: 13, max: 15),
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              ResponsiveGap.vertical(20),

                              // Buttons
                              Column(
                                children: [
                                  // Create New Challenge Button - Gradient
                                  SizedBox(
                                    width: double.infinity,
                                    height: r.size(50),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onCreateNewChallenge();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [

                                              AppColors.secondary,
                                              AppColors.secondary,

                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.secondary.withValues(alpha: 0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_circle_outline,
                                                size: r.size(20),
                                              ),
                                              ResponsiveGap.horizontal(8),
                                              Text(
                                                'Create New Challenge',
                                                style: TextStyle(
                                                  fontSize: r.font(15, min: 14, max: 16),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  ResponsiveGap.vertical(10),

                                  // Later Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: r.size(48),
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onDismiss();
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                        ),
                                      ),
                                      child: Text(
                                        'Later',
                                        style: TextStyle(
                                          fontSize: r.font(14, min: 13, max: 15),
                                          fontWeight: FontWeight.w600,
                                        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}