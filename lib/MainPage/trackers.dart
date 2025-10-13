import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/achievements_page.dart';
import '../app_text_styles.dart';

class Trackers extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(int calories) onCaloriesChanged;

  const Trackers({
    super.key,
    this.currentChallenge,
    required this.onCaloriesChanged,
  });

  @override
  State<Trackers> createState() => _TrackersState();
}

class _TrackersState extends State<Trackers> {
  int _currentCalories = 0;
  int _calorieGoal = 2000;
  int _currentBadges = 0;
  int _badgeGoal = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaysData();
  }

  @override
  void didUpdateWidget(Trackers oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates (e.g., challenge changes)
    if (oldWidget.currentChallenge != widget.currentChallenge) {
      _loadTodaysData();
    }
  }

  Future<void> _loadTodaysData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final today = DateTime.now();

      // Get calorie goal (same logic as FoodLogger)
      int goal = 2000;
      if (widget.currentChallenge?.dailyCalorieGoal != null) {
        goal = widget.currentChallenge!.dailyCalorieGoal;
      } else {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) {
          goal = calculatedGoal;
        }
      }

      // Get calories from FoodLogService (same as FoodLogger)
      final totalCalories = widget.currentChallenge != null
          ? (await FoodLogService.getDailyCalories(today, challengeId: widget.currentChallenge!.id)).round()
          : 0;

      debugPrint('📈 Trackers - Total calories for today: $totalCalories');

      if (mounted) {
        setState(() {
          _calorieGoal = goal;
          _currentCalories = totalCalories;
          _isLoading = false;
        });

        debugPrint('📈 Trackers - Updated state: Calories=$_currentCalories/$_calorieGoal');

        // Notify parent components
        widget.onCaloriesChanged(_currentCalories);
      }
    } catch (e) {
      debugPrint('Error loading tracker data: $e');
      if (mounted) {
        setState(() {
          _calorieGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _currentCalories = 0;
          _isLoading = false;
        });

        widget.onCaloriesChanged(0);
      }
    }
  }

  // Public method to refresh data (can be called from parent)
  void refreshData() {
    _loadTodaysData();
  }

  int _calculateChallengeDay() {
    if (widget.currentChallenge == null) return 0;

    final now = DateTime.now();
    final startDate = widget.currentChallenge!.startDate;

    if (now.isBefore(startDate)) return 0;

    final difference = now.difference(startDate).inDays + 1;
    return difference > 0 ? difference : 0;
  }

  int _getChallengeDaysGoal() {
    if (widget.currentChallenge == null) return 30;

    final totalDays = widget.currentChallenge!.endDate
        .difference(widget.currentChallenge!.startDate)
        .inDays + 1;

    return totalDays;
  }

  double _calculateProgress(int current, int goal) {
    if (goal <= 0) return 0.0;
    return (current / goal).clamp(0.0, 1.0);
  }

  Widget _buildTracker(String label, int current, int goal, double progress, {bool isClickable = true}) {
    // Special handling for Badge - it's a button, not a tracker
    if (label == "Badge" || label == "Achievement") {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AchievementsPage(),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gold circle icon (no progress ring) - same size as tracker circles
                Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxWidth.clamp(60.0, 80.0);
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.shade600,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.shade300.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: (size * 0.45).clamp(27.0, 36.0),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Regular tracker for Calories and Streak
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: () {
            // Calories and Streak are auto-synced, so no manual input needed
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular progress ring with fixed aspect ratio
              Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Use the minimum dimension to ensure perfect circle
                      final size = constraints.maxWidth.clamp(60.0, 80.0);
                      return Container(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: size,
                              height: size,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: (size * 0.125).clamp(6.0, 10.0),
                                backgroundColor: AppColors.secondary.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(progress),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${(progress * 100).toInt()}%",
                                  style: TextStyle(
                                    fontSize: (size * 0.2).clamp(12.0, 16.0),
                                    fontWeight: FontWeight.bold,
                                    color: _getProgressColor(progress),
                                  ),
                                ),
                                if (label == "Progress")
                                  Text(
                                    "Day $current",
                                    style: TextStyle(
                                      fontSize: (size * 0.15).clamp(10.0, 12.0),
                                      color: _getProgressColor(progress),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                _getDisplayText(label, current, goal),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  height: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayText(String label, int current, int goal) {
    switch (label) {
      case "Progress":
        return "Day $current/$goal";
      case "Calories":
        return "$current/$goal cal";
      case "Badge":
      case "Achievement":
        return "$current/$goal badges";
      default:
        return "$current/$goal";
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return AppColors.secondary;
    } else if (progress >= 0.7) {
      return AppColors.secondary;
    } else if (progress >= 0.4) {
      return AppColors.secondary;
    } else {
      return AppColors.secondary.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Progress",
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 20),
          Container(
            height: 180,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    // No challenge state
    if (widget.currentChallenge == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trackers",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  "No Active Challenge",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a challenge to start tracking your progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Active challenge state
    final challengeDaysGoal = _getChallengeDaysGoal();
    final currentChallengeDay = _calculateChallengeDay();

    final calorieProgress = _calculateProgress(_currentCalories, _calorieGoal);
    final challengeDayProgress = _calculateProgress(currentChallengeDay, challengeDaysGoal);
    final badgeProgress = _calculateProgress(_currentBadges, _badgeGoal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Progress",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trackers container (Calories and Challenge Day)
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.secondary.shade200, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildTracker("Calories", _currentCalories, _calorieGoal, calorieProgress, isClickable: false),
                      Container(
                        width: 1,
                        color: AppColors.secondary.shade300,
                      ),
                      _buildTracker("Progress", currentChallengeDay, challengeDaysGoal, challengeDayProgress, isClickable: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Badge button (separate from trackers)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.secondary.shade200, width: 1),
                  ),
                  child: _buildTracker("Badge", _currentBadges, _badgeGoal, badgeProgress, isClickable: false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}