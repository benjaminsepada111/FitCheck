import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/weekly_checkin_service.dart';
import 'package:capstone_project/models/weekly_checkin.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/api_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'video_preview_page.dart';

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

class ChallengeSummaryPage extends StatefulWidget {
  final Map<String, dynamic> challenge;

  const ChallengeSummaryPage({super.key, required this.challenge});

  @override
  State<ChallengeSummaryPage> createState() => _ChallengeSummaryPageState();
}

class _ChallengeSummaryPageState extends State<ChallengeSummaryPage> {
  bool isMonthlySelected = false; // Default view: Weekly Summary (false = Weekly, true = Overall)
  bool _isLoading = true;
  List<FlSpot> _dailyCalorieDataPoints = [];
  List<FlSpot> _weeklyCalorieDataPoints = [];
  List<FlSpot> _monthlyCalorieDataPoints = [];
  Map<int, List<FlSpot>> _weeklyDailyData = {}; // Data for each week
  List<String> _monthKeys = []; // Month keys for label display
  double _minDailyCalories = 0;
  double _maxDailyCalories = 2500;
  double _minWeeklyCalories = 0;
  double _maxWeeklyCalories = 2500;
  double _minMonthlyCalories = 0;
  double _maxMonthlyCalories = 2500;
  int _totalDays = 0;
  int _totalWeeks = 0;
  int _totalMonths = 0;
  int _currentWeek = 1;
  int _currentPeriod = 1; // For overall view navigation
  bool _useMonthsForOverall = false;
  List<WeeklyCheckIn> _weeklyCheckIns = []; // Weekly check-in history
  bool _isLoadingWeeklyCheckIns = false; // Loading state for weekly check-ins

  // Calories burned data
  List<FlSpot> _dailyCaloriesBurnedDataPoints = [];
  List<FlSpot> _weeklyCaloriesBurnedDataPoints = [];
  List<FlSpot> _monthlyCaloriesBurnedDataPoints = [];
  Map<int, List<FlSpot>> _weeklyDailyBurnedData = {}; // Burned data for each week
  double _minDailyBurned = 0;
  double _maxDailyBurned = 500;
  double _minWeeklyBurned = 0;
  double _maxWeeklyBurned = 500;
  double _minMonthlyBurned = 0;
  double _maxMonthlyBurned = 500;

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
    _loadChallengeData();
    _loadMilestones(); // This will also load cached video URL after milestones load
  }

  // ======================
  // VIDEO GENERATION - CACHE MANAGEMENT
  // ======================

  String _getImageHash() {
    // Create a hash from all image URLs/paths to detect changes
    final imageData = _milestones.map((m) {
      return '${m.imageUrl ?? m.imagePath ?? ''}';
    }).join('|');

    // Simple hash: sum of all character codes
    int hash = 0;
    for (int i = 0; i < imageData.length; i++) {
      hash = (hash + imageData.codeUnitAt(i)) % 1000000;
    }

    return hash.toString();
  }

  String _getCacheKey() {
    final challengeId = widget.challenge['challengeId'] as String?;
    final imageHash = _getImageHash();
    return 'video_cache_${challengeId}_${_milestones.length}_$imageHash';
  }

  String _getTextLogsCacheKey() {
    final challengeId = widget.challenge['challengeId'] as String?;
    return 'text_logs_cache_${challengeId}_${_milestones.length}';
  }

  Future<void> _loadCachedVideoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final textLogsCacheKey = _getTextLogsCacheKey();

      print('🎥 Loading cached video URL...');
      print('   Cache key: $cacheKey');

      final cachedUrl = prefs.getString(cacheKey);
      final cachedLogsJson = prefs.getString(textLogsCacheKey);

      print('   Cached URL: ${cachedUrl != null ? "Found" : "Not found"}');
      print('   Cached Logs: ${cachedLogsJson != null ? "Found" : "Not found"}');

      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        setState(() {
          _cachedVideoUrl = cachedUrl;

          // Load cached text logs if available
          if (cachedLogsJson != null) {
            try {
              _cachedTextLogs = List<String>.from(jsonDecode(cachedLogsJson));
              print('   ✅ Loaded ${_cachedTextLogs?.length} cached text logs');
            } catch (e) {
              print('   ⚠️ Failed to decode cached text logs: $e');
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

  Future<void> _clearCachedVideoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final textLogsCacheKey = _getTextLogsCacheKey();

      await prefs.remove(cacheKey);
      await prefs.remove(textLogsCacheKey);

      print('✅ Cleared video and text logs cache');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // ======================
  // MILESTONE & DAILY LOGS LOADING
  // ======================

  Future<void> _loadMilestones() async {
    try {
      final challengeId = widget.challenge['challengeId'] as String?;
      print('📸 Loading milestones for challenge: $challengeId');

      if (challengeId == null) {
        print('❌ Challenge ID is null');
        return;
      }

      // Load ALL milestones (not just those with imageUrl)
      final allMilestones = await MilestoneService.getAllMilestones(
        challengeId: challengeId,
        limit: 100,
      );

      print('📊 Loaded ${allMilestones.length} total milestones');

      // Filter client-side for milestones that have either imageUrl OR imagePath
      final milestonesWithImages = allMilestones.where((m) {
        final hasImage = (m.imageUrl != null && m.imageUrl!.isNotEmpty) ||
            (m.imagePath != null && m.imagePath!.isNotEmpty);
        if (hasImage) {
          print('   ✅ Milestone ${m.id}: imageUrl=${m.imageUrl != null}, imagePath=${m.imagePath != null}');
        }
        return hasImage;
      }).toList();

      // ✅ CRITICAL: Sort by date in ASCENDING order (oldest to newest)
      // This creates a chronological milestone journey: Dec 6 → Dec 7 → Dec 8
      milestonesWithImages.sort((a, b) => a.date.compareTo(b.date));

      print('✅ Found ${milestonesWithImages.length} milestones with images (sorted chronologically)');
      if (milestonesWithImages.isNotEmpty) {
        print('   📅 First: ${DateFormat('MMM d').format(milestonesWithImages.first.date)}');
        print('   📅 Last: ${DateFormat('MMM d').format(milestonesWithImages.last.date)}');
      }

      setState(() {
        _milestones = milestonesWithImages;
      });

      // Load cached video URL after milestones are loaded
      // (cache key depends on milestones)
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
      final challengeId = widget.challenge['challengeId'] as String? ?? '';

      // Get calorie goal
      int goal = widget.challenge['originalCalorieGoal'] ??
          widget.challenge['dailyCalorieGoal'] ??
          2000;

      for (var milestone in _milestones) {
        final date = milestone.date;

        // Load food logs
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

        // Load workouts
        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: challengeId,
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

      // ✅ CRITICAL: Load daily logs FIRST
      print('📊 Loading daily logs for ${_milestones.length} milestones...');
      await _loadDailyLogs();

      print('✅ Daily logs loaded: ${_dailyLogs.length} entries');

      if (!mounted) return;
      Navigator.pop(context);
      _showLoadingDialog('Preparing ${_milestones.length} images with text overlays...');

      // ✅ Milestones are already sorted chronologically (oldest to newest)
      // No need to reverse - video will show: Dec 6 → Dec 7 → Dec 8
      print('📹 Creating video with ${_milestones.length} milestones in chronological order');
      if (_milestones.isNotEmpty) {
        print('   📅 Video starts: ${DateFormat('MMM d').format(_milestones.first.date)}');
        print('   📅 Video ends: ${DateFormat('MMM d').format(_milestones.last.date)}');
      }

      // Process ALL milestones and generate text logs
      for (int i = 0; i < _milestones.length; i++) {
        final m = _milestones[i];
        File? imageFile;
        bool imageAdded = false;

        // Priority 1: Use local imagePath if exists
        if (m.imagePath != null) {
          final f = File(m.imagePath!);
          if (await f.exists()) {
            imageFile = f;
            imageAdded = true;
            print('🖼️ Milestone ${i+1}: Using local image');
          }
        }

        // Priority 2: Download from imageUrl if exists
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
              print('🖼️ Milestone ${i+1}: Downloaded from URL');
            }
          } catch (e) {
            print('❌ Error downloading image ${i+1}: $e');
          }
        }

        // ✅ Only add text log if image was successfully obtained
        if (imageAdded && imageFile != null) {
          // Generate FULL text log for this milestone
          final logData = _dailyLogs[m.date.toString()];
          String fullTextLog = '';

          if (logData != null) {
            fullTextLog = logData.generateTextLog();
            print('📝 Milestone ${i+1}: Generated full log (${fullTextLog.length} chars)');
          } else if (m.notes != null && m.notes!.isNotEmpty) {
            final dateStr = DateFormat('MMM d, yyyy').format(m.date);
            fullTextLog = '$dateStr\n\n${m.notes!}';
            print('📝 Milestone ${i+1}: Using notes fallback');
          } else {
            final dateStr = DateFormat('MMMM d, yyyy').format(m.date);
            fullTextLog = '$dateStr\n\nNo activity logged for this day';
            print('📝 Milestone ${i+1}: Using minimal fallback');
          }

          // Add BOTH image and text log together
          filesToUpload.add(imageFile);
          textLogs.add(fullTextLog);

          print('✅ Milestone ${i+1}: Added image + text log (${filesToUpload.length} total)');
        } else {
          print('⚠️ WARNING: Skipping milestone ${i+1} - no valid image');
        }
      }

      print('📊 Final validation: ${filesToUpload.length} images = ${textLogs.length} text logs');

      if (filesToUpload.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('No image files available to upload');
        setState(() => _isExporting = false);
        return;
      }

      // Update loading message
      if (mounted) {
        Navigator.pop(context);
        _showLoadingDialog('Uploading ${filesToUpload.length} images with text overlays...');
      }

      // Call API to generate video
      final response = await ApiService.generateVideo(
        images: filesToUpload,
        notes: textLogs,
        musicFile: null,
        musicUrl: null,
        durationPerImage: 2,
      );

      // Extract render ID
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
        // CACHE THE VIDEO URL AND TEXT LOGS
        setState(() {
          _cachedVideoUrl = resultUrl;
          _cachedTextLogs = textLogs;
          _isExporting = false;
        });

        // Save to SharedPreferences for persistence
        await _saveCachedVideoUrl(resultUrl, textLogs);

        print('✅ Video generation complete!');
        print('📹 Video URL: $resultUrl');
        print('📝 Cached ${textLogs.length} text logs');

        // Show video ready dialog with navigation option
        _showVideoReadyDialog(resultUrl, textLogs);
      } else {
        _showSnackBar(
            'Render timeout after $attempt attempts. Video may still be processing.');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Export failed: ${e.toString()}');
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

  Future<void> _loadChallengeData() async {
    setState(() {
      _isLoading = true;
      _isLoadingWeeklyCheckIns = true;
    });

    try {
      final challengeId = widget.challenge['challengeId'] as String?;
      if (challengeId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final startDate = widget.challenge['startDate'] as DateTime;
      final endDate = widget.challenge['endDate'] as DateTime;

      // Calculate total days
      final totalDays = endDate.difference(startDate).inDays + 1;

      // Calculate total calories consumed and build data points
      List<FlSpot> dataPoints = [];
      List<double> calorieValues = [];

      // Calculate calories burned and build data points
      List<FlSpot> burnedDataPoints = [];
      List<double> burnedValues = [];

      // Get user weight for calorie burn calculation
      final userData = await UserDataService.loadUserData();
      final userWeight = userData?.weight?.toDouble() ?? 70.0;

      // Loop through each day of the challenge
      int dayIndex = 0;
      for (DateTime date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))) {

        // Get calories for this day
        final dailyCalories = await FoodLogService.getDailyCalories(date, challengeId: challengeId);

        // Get workouts and calculate calories burned for this day
        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: challengeId,
          date: date,
        );

        double caloriesBurned = 0;
        for (var workout in workouts) {
          caloriesBurned += workout.calculateCaloriesBurned(userWeight);
        }

        // Add data point for chart (x = day number, y = calories)
        dayIndex++;
        dataPoints.add(FlSpot(dayIndex.toDouble(), dailyCalories));
        calorieValues.add(dailyCalories);

        burnedDataPoints.add(FlSpot(dayIndex.toDouble(), caloriesBurned));
        burnedValues.add(caloriesBurned);
      }

      // Calculate min and max for chart scaling
      double minCal = 0;
      double maxCal = 2500;
      if (calorieValues.isNotEmpty) {
        minCal = calorieValues.reduce((a, b) => a < b ? a : b);
        maxCal = calorieValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxCal - minCal) * 0.2;
        minCal = (minCal - padding).clamp(0, double.infinity);
        maxCal = maxCal + padding;
      }

      // Calculate min and max for burned calories chart scaling
      double minBurned = 0;
      double maxBurned = 500;
      if (burnedValues.isNotEmpty) {
        minBurned = burnedValues.reduce((a, b) => a < b ? a : b);
        maxBurned = burnedValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxBurned - minBurned) * 0.2;
        minBurned = (minBurned - padding).clamp(0, double.infinity);
        maxBurned = maxBurned + padding;
      }

      // Calculate total weeks based on challenge duration (not just data available)
      final challengeDuration = endDate.difference(startDate).inDays + 1;
      final totalWeeksInChallenge = (challengeDuration / 7).ceil();
      final now = DateTime.now();

      // Calculate weekly data (for Overall view - shows average per week)
      List<FlSpot> weeklyDataPoints = [];
      List<double> weeklyCalorieValues = [];
      List<FlSpot> weeklyBurnedDataPoints = [];
      List<double> weeklyBurnedValues = [];
      int weekIndex = 0;

      // Also store daily data per week (for Weekly Summary view)
      Map<int, List<FlSpot>> weeklyDailyData = {};
      Map<int, List<FlSpot>> weeklyDailyBurnedData = {};

      // Create weekly data for all weeks
      for (int weekNum = 1; weekNum <= totalWeeksInChallenge; weekNum++) {
        weekIndex = weekNum;

        // Calculate which days belong to this week
        int startDayIndex = (weekNum - 1) * 7;
        int endDayIndex = startDayIndex + 6;

        // Check if this week is completed (all 7 days have passed)
        final weekEndDate = startDate.add(Duration(days: endDayIndex));
        final isWeekCompleted = now.isAfter(weekEndDate);

        double weeklyCalories = 0;
        double weeklyBurned = 0;
        int daysInWeek = 0;
        List<FlSpot> weekDays = [];
        List<FlSpot> weekBurnedDays = [];

        // Collect data for this week (only if data exists)
        for (int dayIndex = startDayIndex; dayIndex <= endDayIndex && dayIndex < dataPoints.length; dayIndex++) {
          weeklyCalories += dataPoints[dayIndex].y;
          weeklyBurned += burnedDataPoints[dayIndex].y;
          daysInWeek++;
          // Store daily data for this week (day 1-7 of the week)
          weekDays.add(FlSpot((daysInWeek).toDouble(), dataPoints[dayIndex].y));
          weekBurnedDays.add(FlSpot((daysInWeek).toDouble(), burnedDataPoints[dayIndex].y));
        }

        // Store weekly daily data for Weekly Summary view (all weeks)
        weeklyDailyData[weekIndex] = weekDays;
        weeklyDailyBurnedData[weekIndex] = weekBurnedDays;

        // For Overall view: only include COMPLETED weeks with full 7 days of data
        if (isWeekCompleted && daysInWeek == 7) {
          double avgCalories = weeklyCalories / 7;
          double avgBurned = weeklyBurned / 7;
          weeklyDataPoints.add(FlSpot(weekNum.toDouble(), avgCalories));
          weeklyCalorieValues.add(avgCalories);
          weeklyBurnedDataPoints.add(FlSpot(weekNum.toDouble(), avgBurned));
          weeklyBurnedValues.add(avgBurned);
        }
      }

      // Calculate min and max for weekly chart scaling
      double minWeeklyCal = 0;
      double maxWeeklyCal = 2500;
      if (weeklyCalorieValues.isNotEmpty) {
        minWeeklyCal = weeklyCalorieValues.reduce((a, b) => a < b ? a : b);
        maxWeeklyCal = weeklyCalorieValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxWeeklyCal - minWeeklyCal) * 0.2;
        minWeeklyCal = (minWeeklyCal - padding).clamp(0, double.infinity);
        maxWeeklyCal = maxWeeklyCal + padding;
      }

      // Calculate min and max for weekly burned chart scaling
      double minWeeklyBurned = 0;
      double maxWeeklyBurned = 500;
      if (weeklyBurnedValues.isNotEmpty) {
        minWeeklyBurned = weeklyBurnedValues.reduce((a, b) => a < b ? a : b);
        maxWeeklyBurned = weeklyBurnedValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxWeeklyBurned - minWeeklyBurned) * 0.2;
        minWeeklyBurned = (minWeeklyBurned - padding).clamp(0, double.infinity);
        maxWeeklyBurned = maxWeeklyBurned + padding;
      }

      // Calculate monthly data if challenge is >= 3 months
      List<FlSpot> monthlyDataPoints = [];
      List<double> monthlyCalorieValues = [];
      List<FlSpot> monthlyBurnedDataPoints = [];
      List<double> monthlyBurnedValues = [];
      List<String> monthKeys = []; // Store month keys for label display
      int monthIndex = 0;
      bool useMonths = totalDays >= 90; // 3+ months

      if (useMonths) {
        // Group by actual calendar months
        Map<String, List<double>> monthlyData = {};
        Map<String, List<double>> monthlyBurnedData = {};
        List<String> orderedMonthKeys = [];

        DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
        final endMonth = DateTime(endDate.year, endDate.month, 1);

        // Create ordered list of months
        while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
          String monthKey = '${currentMonth.year}-${currentMonth.month}';
          orderedMonthKeys.add(monthKey);
          monthlyData[monthKey] = [];
          monthlyBurnedData[monthKey] = [];
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
        }

        // Fill in the data
        for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {

          String monthKey = '${date.year}-${date.month}';

          // Find the corresponding calorie data
          int daysSinceStart = date.difference(startDate).inDays;
          if (daysSinceStart < calorieValues.length && monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey]!.add(calorieValues[daysSinceStart]);
            monthlyBurnedData[monthKey]!.add(burnedValues[daysSinceStart]);
          }
        }

        // Calculate averages for each month in order
        monthIndex = 0;
        for (String key in orderedMonthKeys) {
          monthIndex++;
          monthKeys.add(key);
          double avgCalories = monthlyData[key]!.isEmpty
              ? 0
              : monthlyData[key]!.reduce((a, b) => a + b) / monthlyData[key]!.length;
          double avgBurned = monthlyBurnedData[key]!.isEmpty
              ? 0
              : monthlyBurnedData[key]!.reduce((a, b) => a + b) / monthlyBurnedData[key]!.length;
          monthlyDataPoints.add(FlSpot(monthIndex.toDouble(), avgCalories));
          monthlyCalorieValues.add(avgCalories);
          monthlyBurnedDataPoints.add(FlSpot(monthIndex.toDouble(), avgBurned));
          monthlyBurnedValues.add(avgBurned);
        }
      }

      // Calculate min and max for monthly chart scaling
      double minMonthlyCal = 0;
      double maxMonthlyCal = 2500;
      if (monthlyCalorieValues.isNotEmpty) {
        minMonthlyCal = monthlyCalorieValues.reduce((a, b) => a < b ? a : b);
        maxMonthlyCal = monthlyCalorieValues.reduce((a, b) => a > b ? a : b);

        final padding = (maxMonthlyCal - minMonthlyCal) * 0.2;
        minMonthlyCal = (minMonthlyCal - padding).clamp(0, double.infinity);
        maxMonthlyCal = maxMonthlyCal + padding;
      }

      // Calculate min and max for monthly burned chart scaling
      double minMonthlyBurned = 0;
      double maxMonthlyBurned = 500;
      if (monthlyBurnedValues.isNotEmpty) {
        minMonthlyBurned = monthlyBurnedValues.reduce((a, b) => a < b ? a : b);
        maxMonthlyBurned = monthlyBurnedValues.reduce((a, b) => a > b ? a : b);

        final padding = (maxMonthlyBurned - minMonthlyBurned) * 0.2;
        minMonthlyBurned = (minMonthlyBurned - padding).clamp(0, double.infinity);
        maxMonthlyBurned = maxMonthlyBurned + padding;
      }

      // Load weekly check-ins for this challenge
      final checkIns = await WeeklyCheckInService.getCheckInsForChallenge(challengeId);

      setState(() {
        _dailyCalorieDataPoints = dataPoints;
        _weeklyCalorieDataPoints = weeklyDataPoints;
        _monthlyCalorieDataPoints = monthlyDataPoints;
        _weeklyDailyData = weeklyDailyData;
        _dailyCaloriesBurnedDataPoints = burnedDataPoints;
        _weeklyCaloriesBurnedDataPoints = weeklyBurnedDataPoints;
        _monthlyCaloriesBurnedDataPoints = monthlyBurnedDataPoints;
        _weeklyDailyBurnedData = weeklyDailyBurnedData;
        _monthKeys = monthKeys;
        _minDailyCalories = minCal;
        _maxDailyCalories = maxCal;
        _minWeeklyCalories = minWeeklyCal;
        _maxWeeklyCalories = maxWeeklyCal;
        _minMonthlyCalories = minMonthlyCal;
        _maxMonthlyCalories = maxMonthlyCal;
        _minDailyBurned = minBurned;
        _maxDailyBurned = maxBurned;
        _minWeeklyBurned = minWeeklyBurned;
        _maxWeeklyBurned = maxWeeklyBurned;
        _minMonthlyBurned = minMonthlyBurned;
        _maxMonthlyBurned = maxMonthlyBurned;
        _totalDays = totalDays;
        _totalWeeks = weekIndex;
        _totalMonths = monthIndex;
        _useMonthsForOverall = useMonths;
        _currentWeek = 1;
        _currentPeriod = 1;
        _weeklyCheckIns = checkIns;
        _isLoading = false;
        _isLoadingWeeklyCheckIns = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingWeeklyCheckIns = false;
      });
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateDuration(Map<String, dynamic> challenge) {
    if (challenge['startDate'] == null || challenge['endDate'] == null) return 0;
    final startDate = challenge['startDate'] as DateTime;
    final endDate = challenge['endDate'] as DateTime;
    return endDate.difference(startDate).inDays + 1;
  }

  bool _isChallengeCompleted() {
    final endDate = widget.challenge['endDate'] as DateTime?;
    final status = widget.challenge['status'] as String?;

    print('🔍 Checking if challenge is completed:');
    print('   End Date: $endDate');
    print('   Status: $status');
    print('   Current Date: ${DateTime.now()}');

    if (endDate == null) {
      print('   ❌ End date is null');
      return false;
    }

    final isAfterEndDate = DateTime.now().isAfter(endDate.add(const Duration(days: 1)));
    print('   Is after end date: $isAfterEndDate');

    // Also check status field if available
    if (status != null && status.toLowerCase() == 'completed') {
      print('   ✅ Challenge marked as completed');
      return true;
    }

    return isAfterEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Challenge History',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          // Refresh button to reload milestones
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () async {
              print('🔄 Manual refresh triggered');
              await _loadMilestones();
              _showSnackBar('Milestones refreshed');
            },
            tooltip: 'Refresh milestones',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          print('🔄 Pull-to-refresh triggered');
          await Future.wait([
            _loadChallengeData(),
            _loadMilestones(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildChallengeCard(widget.challenge),
              const SizedBox(height: 24),

              // ✅ Generate Video Button - Show when challenge is completed
              if (_isChallengeCompleted()) ...[
                Builder(
                  builder: (context) {
                    print('🎬 Rendering video button:');
                    print('   Milestones count: ${_milestones.length}');
                    print('   Is loading: $_isLoading');
                    print('   Is exporting: $_isExporting');
                    return _buildGenerateVideoButton();
                  },
                ),
                const SizedBox(height: 24),
              ],

              _buildSummaryButtons(),
              const SizedBox(height: 16),
              _buildPeriodNavigation(),
              const SizedBox(height: 24),
              _buildCalorieProgressChart(),
              const SizedBox(height: 24),
              _buildCalorieBurnedChart(),
              const SizedBox(height: 24),
              // Show Weight Progress chart only in Overall view
              if (isMonthlySelected) ...[
                _buildWeightProgressChart(),
                const SizedBox(height: 24),
              ],
              _buildWeeklyProgressSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Generate Video Button Widget
  Widget _buildGenerateVideoButton() {
    final hasVideo = _cachedVideoUrl != null && _cachedVideoUrl!.isNotEmpty;
    final hasMilestones = _milestones.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: hasMilestones
            ? LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.shade600,
          ],
        )
            : null,
        color: hasMilestones ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasMilestones
            ? [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isExporting || !hasMilestones) ? null : _generateMilestoneVideo,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasMilestones
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isExporting
                        ? Icons.hourglass_empty
                        : hasMilestones
                        ? (hasVideo ? Icons.video_library : Icons.video_call)
                        : Icons.photo_library_outlined,
                    color: hasMilestones ? Colors.white : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isExporting
                            ? 'Generating Video...'
                            : hasMilestones
                            ? (hasVideo ? 'Open Milestone Video' : 'Generate Milestone Video')
                            : 'No Milestone Photos',
                        style: TextStyle(
                          color: hasMilestones ? Colors.white : Colors.grey.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isExporting
                            ? 'Please wait while we create your video'
                            : hasMilestones
                            ? (hasVideo
                            ? 'Your milestone journey video is ready'
                            : '${_milestones.length} milestone photos available')
                            : 'Add photos to your milestone journey to create a video',
                        style: TextStyle(
                          color: hasMilestones
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExporting
                      ? Icons.more_horiz
                      : hasMilestones
                      ? Icons.arrow_forward_ios
                      : Icons.info_outline,
                  color: hasMilestones ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    challenge['title'] ?? 'Challenge',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    challenge['status'] ?? 'Completed',
                    style: TextStyle(
                      color: AppColors.secondary.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppColors.secondary.shade600),
                const SizedBox(width: 8),
                Text(
                  challenge['dateRange'] ?? 'No dates',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress
            const Text(
              'Progress',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (challenge['progress'] ?? 100) / 100.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.secondary.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${challenge['progress'] ?? 100}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Stats
            _isLoading
                ? const Center(child: FitCheckLoader())
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.restaurant,
                  label: 'Daily Calorie',
                  value: '${widget.challenge['originalCalorieGoal'] ?? widget.challenge['dailyCalorieGoal'] ?? 'N/A'}',
                  color: AppColors.secondary,
                ),
                _buildStatItem(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Starting Weight',
                  value: widget.challenge['originalWeight'] != null
                      ? '${widget.challenge['originalWeight']}kg'
                      : 'N/A',
                  color: AppColors.secondary,
                ),
                _buildStatItem(
                  icon: Icons.access_time,
                  label: 'Duration',
                  value: '${_calculateDuration(widget.challenge)} Days',
                  color: AppColors.secondary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notes
            if (challenge['notes'] != null && (challenge['notes'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 16,
                          color: AppColors.secondary.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      challenge['notes'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isMonthlySelected = false;
                  _currentWeek = 1; // Reset to week 1 when switching
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !isMonthlySelected ? AppColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isMonthlySelected
                      ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  'Weekly Summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isMonthlySelected ? Colors.white : Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isMonthlySelected = true;
                  _currentPeriod = 1; // Reset to period 1 when switching
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isMonthlySelected ? AppColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isMonthlySelected
                      ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  'Overall',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isMonthlySelected ? Colors.white : Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodNavigation() {
    if (_isLoading) return const SizedBox.shrink();

    final isWeekly = !isMonthlySelected;

    if (isWeekly) {
      // Weekly Summary: show week selection buttons
      if (_totalWeeks <= 1) return const SizedBox.shrink();

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_totalWeeks, (index) {
            final weekNumber = index + 1;
            final isSelected = weekNumber == _currentWeek;

            return Padding(
              padding: EdgeInsets.only(
                right: index == _totalWeeks - 1 ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentWeek = weekNumber;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [
                        AppColors.secondary,
                        AppColors.secondary.shade600,
                      ],
                    )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.secondary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Text(
                    'Week $weekNumber',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.secondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    } else {
      // Overall: no navigation needed for overall view showing all data
      return const SizedBox.shrink();
    }
  }


  Widget _buildCalorieProgressChart() {
    // Show loading or empty state
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: FitCheckLoader(
          ),
        ),
      );
    }

    // Determine which data to show based on selection
    // Weekly Summary = daily data for a specific week
    // Overall = weekly or monthly data for the entire challenge
    final isWeekly = !isMonthlySelected;

    List<FlSpot> dataPoints;
    double minCalories;
    double maxCalories;
    int totalPeriods;
    String periodLabel;

    if (isWeekly) {
      // Weekly Summary: show daily data for current week
      dataPoints = _weeklyDailyData[_currentWeek] ?? [];
      minCalories = _minDailyCalories;
      maxCalories = _maxDailyCalories;
      // Show all 7 days on x-axis even if only partial data
      totalPeriods = 7;
      periodLabel = 'DAY';
    } else {
      // Overall: show weekly or monthly data
      if (_useMonthsForOverall) {
        dataPoints = _monthlyCalorieDataPoints;
        minCalories = _minMonthlyCalories;
        maxCalories = _maxMonthlyCalories;
        totalPeriods = _totalMonths;
        periodLabel = 'WEEK';
      } else {
        dataPoints = _weeklyCalorieDataPoints;
        minCalories = _minWeeklyCalories;
        maxCalories = _maxWeeklyCalories;
        totalPeriods = _totalWeeks;
        periodLabel = 'WEEK';
      }
    }

    // Get dates early for use in empty states
    final startDate = widget.challenge['startDate'] as DateTime;
    final endDate = widget.challenge['endDate'] as DateTime;

    if (dataPoints.isEmpty) {
      // For Weekly Summary with no data: show empty state
      if (isWeekly) {
        final weekStartDay = (_currentWeek - 1) * 7;
        final weekStart = startDate.add(Duration(days: weekStartDay));
        final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
        final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
        String dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.15),
                            AppColors.secondary.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.show_chart,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calorie Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          dateRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 48,
                          color: AppColors.secondary.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No data for Week $_currentWeek yet',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Data will appear as you log calories',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
      // For Overall view with no data: show empty state
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.show_chart,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calorie Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_outlined,
                        size: 48,
                        color: AppColors.secondary.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No calorie data yet',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start logging your meals to track progress',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    // Format date range based on view
    String dateRange;

    if (isWeekly) {
      // Show date range for current week
      final weekStartDay = (_currentWeek - 1) * 7;
      final weekStart = startDate.add(Duration(days: weekStartDay));
      final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
      final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
      dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';
    } else {
      // Show full date range
      dateRange = '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}';
    }

    // Calculate interval for y-axis
    final range = maxCalories - minCalories;
    final interval = (range / 4).roundToDouble().clamp(100.0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.show_chart,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calorie Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              // Only show labels for integer values to avoid duplicates
                              if (value != value.roundToDouble()) {
                                return const Text('');
                              }

                              final period = value.toInt();
                              if (period >= 1 && period <= totalPeriods) {
                                // Show month names if using monthly view
                                if (!isWeekly && _useMonthsForOverall) {
                                  // Get month from stored keys
                                  if (period - 1 < _monthKeys.length) {
                                    final monthKey = _monthKeys[period - 1];
                                    final parts = monthKey.split('-');
                                    if (parts.length == 2) {
                                      final month = int.parse(parts[1]);
                                      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          months[month - 1],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Show numbers for weekly or daily view
                                  // For weekly/daily: show all numbers if <= 10 periods, otherwise show first and last
                                  if (totalPeriods <= 10) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        period.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  } else if (period == 1 || period == totalPeriods) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        period.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 1,
                      maxX: totalPeriods.toDouble(),
                      minY: minCalories,
                      maxY: maxCalories,
                      lineBarsData: dataPoints.isEmpty
                          ? []
                          : [
                        LineChartBarData(
                          spots: dataPoints,
                          isCurved: false,
                          color: AppColors.secondary,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.secondary,
                                strokeColor: Colors.white,
                                strokeWidth: 2,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                  // Transparent overlay when no data in Overall view
                  if (!isWeekly && dataPoints.isEmpty)
                    Container(
                      color: Colors.white.withValues(alpha: 0.85),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No completed weeks yet',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Data will appear after a full week',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                periodLabel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildCalorieBurnedChart() {
    // Show loading state
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
      );
    }

    final startDate = widget.challenge['startDate'] as DateTime;
    final endDate = widget.challenge['endDate'] as DateTime;

    // Determine which data to display based on current view
    List<FlSpot> dataPoints;
    double minBurned;
    double maxBurned;
    int totalPeriods;
    String periodLabel;
    bool isWeekly = !isMonthlySelected;

    if (isWeekly) {
      // Weekly Summary: show daily data for current week
      dataPoints = _weeklyDailyBurnedData[_currentWeek] ?? [];
      minBurned = _minDailyBurned;
      maxBurned = _maxDailyBurned;
      totalPeriods = 7;
      periodLabel = 'DAY';
    } else {
      // Overall: show weekly or monthly data
      if (_useMonthsForOverall) {
        dataPoints = _monthlyCaloriesBurnedDataPoints;
        minBurned = _minMonthlyBurned;
        maxBurned = _maxMonthlyBurned;
        totalPeriods = _totalMonths;
        periodLabel = 'WEEK';
      } else {
        dataPoints = _weeklyCaloriesBurnedDataPoints;
        minBurned = _minWeeklyBurned;
        maxBurned = _maxWeeklyBurned;
        totalPeriods = _totalWeeks;
        periodLabel = 'WEEK';
      }
    }

    // Handle empty data
    if (dataPoints.isEmpty) {
      // For Weekly Summary with no data: show empty state
      if (isWeekly) {
        // Show date range for current week
        final weekStartDay = (_currentWeek - 1) * 7;
        final weekStart = startDate.add(Duration(days: weekStartDay));
        final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
        final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
        String dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withValues(alpha: 0.15),
                            Colors.orange.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        size: 18,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calories Burned',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          dateRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          size: 48,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No data for Week $_currentWeek yet',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Data will appear as you log workouts',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
      // For Overall view with no data: show empty state
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withValues(alpha: 0.15),
                          Colors.orange.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calories Burned',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        size: 48,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No workout data yet',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start logging your workouts to track calories burned',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    // Format date range based on view
    String dateRange;

    if (isWeekly) {
      // Show date range for current week
      final weekStartDay = (_currentWeek - 1) * 7;
      final weekStart = startDate.add(Duration(days: weekStartDay));
      final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
      final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
      dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';
    } else {
      // Show full date range
      dateRange = '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}';
    }

    // Calculate interval for y-axis
    final range = maxBurned - minBurned;
    final interval = (range / 4).roundToDouble().clamp(100.0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withValues(alpha: 0.15),
                        Colors.orange.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calories Burned',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              // Only show labels for integer values to avoid duplicates
                              if (value != value.roundToDouble()) {
                                return const Text('');
                              }

                              final period = value.toInt();
                              if (period >= 1 && period <= totalPeriods) {
                                // Show month names if using monthly view
                                if (!isWeekly && _useMonthsForOverall) {
                                  // Get month from stored keys
                                  if (period - 1 < _monthKeys.length) {
                                    final monthKey = _monthKeys[period - 1];
                                    final parts = monthKey.split('-');
                                    if (parts.length == 2) {
                                      final month = int.parse(parts[1]);
                                      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          months[month - 1],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Show numbers for weekly or daily view
                                  // For weekly/daily: show all numbers if <= 10 periods, otherwise show first and last
                                  if (totalPeriods <= 10) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        period.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  } else if (period == 1 || period == totalPeriods) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        period.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 1,
                      maxX: totalPeriods.toDouble(),
                      minY: minBurned,
                      maxY: maxBurned,
                      lineBarsData: dataPoints.isEmpty
                          ? []
                          : [
                        LineChartBarData(
                          spots: dataPoints,
                          isCurved: false,
                          color: Colors.orange,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.orange,
                                strokeColor: Colors.white,
                                strokeWidth: 2,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                  // Transparent overlay when no data in Overall view
                  if (!isWeekly && dataPoints.isEmpty)
                    Container(
                      color: Colors.white.withValues(alpha: 0.85),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No completed weeks yet',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Data will appear after a full week',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                periodLabel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightProgressChart() {
    // Show loading state
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
      );
    }

    // Get weight data from weekly check-ins
    if (_weeklyCheckIns.isEmpty) {
      // Show empty state when no check-ins available
      final startDate = widget.challenge['startDate'] as DateTime;
      final endDate = widget.challenge['endDate'] as DateTime;
      String dateRange = '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}';

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.monitor_weight,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weight Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.scale_outlined,
                        size: 48,
                        color: AppColors.secondary.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No weight data yet',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete weekly check-ins to track weight progress',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    // Build data points from check-ins
    List<FlSpot> weightDataPoints = [];
    List<double> weightValues = [];

    for (var checkIn in _weeklyCheckIns) {
      weightDataPoints.add(FlSpot(checkIn.weekNumber.toDouble(), checkIn.currentWeight.toDouble()));
      weightValues.add(checkIn.currentWeight.toDouble());
    }

    // Calculate min and max for chart scaling
    double minWeight = weightValues.reduce((a, b) => a < b ? a : b);
    double maxWeight = weightValues.reduce((a, b) => a > b ? a : b);

    // Add padding to min/max
    final padding = (maxWeight - minWeight) * 0.2;
    minWeight = (minWeight - padding).clamp(0, double.infinity);
    maxWeight = maxWeight + padding;

    final startDate = widget.challenge['startDate'] as DateTime;
    final endDate = widget.challenge['endDate'] as DateTime;
    String dateRange = '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}';

    // Calculate interval for y-axis
    final range = maxWeight - minWeight;
    final interval = (range / 4).clamp(1.0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.monitor_weight,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weight Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Only show labels for integer values
                          if (value != value.roundToDouble()) {
                            return const Text('');
                          }

                          final weekNum = value.toInt();
                          if (weekNum >= 1 && weekNum <= _totalWeeks) {
                            // Show week numbers
                            if (_totalWeeks <= 10) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  weekNum.toString(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            } else if (weekNum == 1 || weekNum == _totalWeeks) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  weekNum.toString(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: _totalWeeks.toDouble(),
                  minY: minWeight,
                  maxY: maxWeight,
                  lineBarsData: [
                    LineChartBarData(
                      spots: weightDataPoints,
                      isCurved: false,
                      color: AppColors.secondary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.secondary,
                            strokeColor: Colors.white,
                            strokeWidth: 2,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'WEEK',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressSection() {
    // Show loading state while fetching weekly check-ins
    if (_isLoadingWeeklyCheckIns) {
      return _buildLoadingCheckInCard();
    }

    // FILTER: Only show check-ins for the current selected week in Weekly Summary view
    final isWeekly = !isMonthlySelected;

    if (isWeekly) {
      // Weekly Summary: Show card for current week (with data or empty state)
      final filteredCheckIns = _weeklyCheckIns
          .where((checkIn) => checkIn.weekNumber == _currentWeek)
          .toList();

      if (filteredCheckIns.isEmpty) {
        // Show empty state for this week
        return _buildEmptyCheckInCard();
      } else {
        return _buildCheckInCard(filteredCheckIns.first);
      }
    } else {
      // Overall view: Don't show weekly check-ins section
      return const SizedBox.shrink();
    }
  }

  Widget _buildLoadingCheckInCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching Calorie Progress style
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Check-In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Loading state content
            Center(
              child: Column(
                children: [
                  const FitCheckLoader(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading check-in data...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCheckInCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching Calorie Progress style
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Check-In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Empty state content
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No check-in data yet',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete your weekly check-in to see progress',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard(WeeklyCheckIn checkIn) {
    final weightChangeText = checkIn.weightChange != null
        ? checkIn.weightChange! >= 0
        ? '+${checkIn.weightChange!.toStringAsFixed(1)}kg'
        : '${checkIn.weightChange!.toStringAsFixed(1)}kg'
        : 'N/A';

    final calorieChangeText = checkIn.calorieAdjustment != null && checkIn.calorieAdjustment != 0
        ? checkIn.calorieAdjustment! > 0
        ? '+${checkIn.calorieAdjustment}'
        : '${checkIn.calorieAdjustment}'
        : '0';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching Calorie Progress style
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Check-In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _formatDateShort(checkIn.checkInDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weight and Calorie Info
            _buildInfoRow(
              'Weight',
              '${checkIn.currentWeight}kg',
              weightChangeText,
              checkIn.weightChange != null && checkIn.weightChange! < 0
                  ? Colors.green.shade600
                  : checkIn.weightChange != null && checkIn.weightChange! > 0
                  ? Colors.orange.shade600
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Calorie Goal',
              '${checkIn.newCalorieGoal ?? 'N/A'}',
              calorieChangeText != '0' ? '$calorieChangeText cal' : 'No change',
              checkIn.calorieAdjustment != null && checkIn.calorieAdjustment! != 0
                  ? AppColors.secondary
                  : Colors.grey.shade600,
            ),

            // Notes
            if (checkIn.notes != null && checkIn.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      checkIn.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String change, Color changeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($change)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: changeColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}