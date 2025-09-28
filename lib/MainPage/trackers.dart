import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_storage_service.dart';
import '../app_text_styles.dart';

class Trackers extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(int calories) onCaloriesChanged;
  final Function(int water) onWaterChanged;

  const Trackers({
    super.key,
    this.currentChallenge,
    required this.onCaloriesChanged,
    required this.onWaterChanged,
  });

  @override
  State<Trackers> createState() => _TrackersState();
}

class _TrackersState extends State<Trackers> {
  int _currentCalories = 0;
  int _currentWater = 0;
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

      // Get calories from logged foods automatically
      final totalCalories = await FoodStorageService.getTotalCaloriesForDay(today);

      // Get water intake from storage
      final waterIntake = await WaterStorageService.getWaterIntakeForDate(today);

      if (mounted) {
        setState(() {
          _currentCalories = totalCalories;
          _currentWater = waterIntake;
          _isLoading = false;
        });

        // Notify parent components
        widget.onCaloriesChanged(_currentCalories);
        widget.onWaterChanged(_currentWater);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentCalories = 0;
          _currentWater = 0;
          _isLoading = false;
        });

        widget.onCaloriesChanged(0);
        widget.onWaterChanged(0);
      }
    }
  }

  // Public method to refresh data (can be called from parent)
  void refreshData() {
    _loadTodaysData();
  }

  int _calculateStreak() {
    if (widget.currentChallenge == null) return 0;

    final now = DateTime.now();
    final startDate = widget.currentChallenge!.startDate;

    if (now.isBefore(startDate)) return 0;

    final difference = now.difference(startDate).inDays + 1;
    return difference > 0 ? difference : 0;
  }

  int _getStreakGoal() {
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

  void _showWaterUpdateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WaterIntakeSheet(
        currentWater: _currentWater,
        onWaterUpdated: (newWater) async {
          await WaterStorageService.setWaterIntakeForDate(DateTime.now(), newWater);
          setState(() => _currentWater = newWater);
          widget.onWaterChanged(newWater);
        },
      ),
    );
  }

  Widget _buildTracker(String label, int current, int goal, double progress, {bool isClickable = true}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: () {
            if (label == "Water" && isClickable) {
              _showWaterUpdateSheet();
            }
            // Calories are auto-synced, so no manual input needed
            // Streak is not clickable
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
                                if (label == "Streak")
                                  Text(
                                    "${current}d",
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
      case "Streak":
        return "$current/$goal days";
      case "Water":
        return "$current/$goal glasses";
      case "Calories":
        return "$current/$goal cal";
      default:
        return "$current/$goal";
    }
  }

  String _getStatusText(String label) {
    switch (label) {
      case "Calories":
        return "Auto-synced";
      case "Water":
        return "Tap to update";
      case "Streak":
        return "Auto-tracked";
      default:
        return "";
    }
  }

  Color _getStatusColor(String label) {
    switch (label) {
      case "Calories":
        return Colors.green.withOpacity(0.7);
      case "Water":
        return AppColors.secondary.withOpacity(0.7);
      case "Streak":
        return Colors.blue.withOpacity(0.7);
      default:
        return Colors.grey;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return Colors.green;
    } else if (progress >= 0.7) {
      return AppColors.secondary;
    } else if (progress >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red.shade400;
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
    final calorieGoal = widget.currentChallenge!.dailyCalorieGoal;
    final waterGoal = widget.currentChallenge!.dailyWaterGoal;
    final streakGoal = _getStreakGoal();
    final currentStreak = _calculateStreak();

    final calorieProgress = _calculateProgress(_currentCalories, calorieGoal);
    final waterProgress = _calculateProgress(_currentWater, waterGoal);
    final streakProgress = _calculateProgress(currentStreak, streakGoal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Progress",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTracker("Calories", _currentCalories, calorieGoal, calorieProgress, isClickable: false),
                Container(
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildTracker("Water", _currentWater, waterGoal, waterProgress),
                Container(
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildTracker("Streak", currentStreak, streakGoal, streakProgress, isClickable: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Water Storage Service
class WaterStorageService {
  static const String _waterIntakeKey = 'water_intake';

  static Future<int> getWaterIntakeForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '${_waterIntakeKey}_${_formatDate(date)}';
      return prefs.getInt(dateKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> setWaterIntakeForDate(DateTime date, int glasses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '${_waterIntakeKey}_${_formatDate(date)}';
      await prefs.setInt(dateKey, glasses);
    } catch (e) {
      // Handle error silently
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Water Intake Sheet
class WaterIntakeSheet extends StatefulWidget {
  final int currentWater;
  final Function(int) onWaterUpdated;

  const WaterIntakeSheet({
    super.key,
    required this.currentWater,
    required this.onWaterUpdated,
  });

  @override
  State<WaterIntakeSheet> createState() => _WaterIntakeSheetState();
}

class _WaterIntakeSheetState extends State<WaterIntakeSheet> {
  late int _waterCount;

  @override
  void initState() {
    super.initState();
    _waterCount = widget.currentWater;
  }

  void _updateWater(int change) {
    setState(() {
      _waterCount = (_waterCount + change).clamp(0, 20); // Max 20 glasses
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Water Intake',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your daily water consumption',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),

            // Water visualization
            Expanded(
              child: Column(
                children: [
                  // Large water display
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200, width: 3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_drink,
                          size: 40,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_waterCount',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          'glasses',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildWaterButton(
                        icon: Icons.remove,
                        onPressed: _waterCount > 0 ? () => _updateWater(-1) : null,
                        color: Colors.red.shade400,
                      ),
                      _buildWaterButton(
                        icon: Icons.add,
                        onPressed: () => _updateWater(1),
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick add buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickAddButton('-5', () => _updateWater(-5)),
                      _buildQuickAddButton('+1', () => _updateWater(1)),
                      _buildQuickAddButton('+3', () => _updateWater(3)),
                      _buildQuickAddButton('+5', () => _updateWater(5)),
                    ],
                  ),
                ],
              ),
            ),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onWaterUpdated(_waterCount);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Water Intake',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
          elevation: 0,
        ),
        child: Icon(icon, size: 30),
      ),
    );
  }

  Widget _buildQuickAddButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade700,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}