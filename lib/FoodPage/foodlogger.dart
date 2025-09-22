import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_storage_service.dart';
import 'package:capstone_project/services/user_data_service.dart';

class FoodLogger extends StatefulWidget {
  final Challenge? currentChallenge;
  final VoidCallback? onCaloriesUpdated; // For notifying parent components

  const FoodLogger({
    super.key,
    this.currentChallenge,
    this.onCaloriesUpdated,
  });

  @override
  State<FoodLogger> createState() => _FoodLoggerState();
}

class _FoodLoggerState extends State<FoodLogger> {
  int _dailyGoal = 2000;
  int _consumed = 0;
  bool _isLoading = true;
  bool _hasPersonalizedGoal = false; // Track if goal is personalized or default

  @override
  void initState() {
    super.initState();
    _loadCalorieData();
  }

  @override
  void didUpdateWidget(FoodLogger oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when challenge changes
    if (oldWidget.currentChallenge != widget.currentChallenge) {
      _loadCalorieData();
    }
  }

  Future<void> _loadCalorieData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      int goal = 2000; // Default fallback
      bool isPersonalized = false;

      // Priority 1: Get from current challenge (already calculated using Mifflin-St Jeor)
      if (widget.currentChallenge?.dailyCalorieGoal != null) {
        goal = widget.currentChallenge!.dailyCalorieGoal;
        isPersonalized = true;
      } else {
        // Priority 2: Calculate from user profile using UserDataService
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) { // If not default, it means we have user data
          goal = calculatedGoal;
          isPersonalized = true;
        }
      }

      // Get consumed calories from logged foods
      final today = DateTime.now();
      final consumed = await FoodStorageService.getTotalCaloriesForDay(today);

      if (mounted) {
        setState(() {
          _dailyGoal = goal;
          _consumed = consumed;
          _hasPersonalizedGoal = isPersonalized;
          _isLoading = false;
        });

        // Notify parent if calories were updated
        if (widget.onCaloriesUpdated != null) {
          widget.onCaloriesUpdated!();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback: try to get from challenge, then default to 2000
          _dailyGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _consumed = 0;
          _hasPersonalizedGoal = widget.currentChallenge?.dailyCalorieGoal != null;
          _isLoading = false;
        });
      }
    }
  }

  // Public method to refresh data (can be called from parent)
  void refreshData() {
    _loadCalorieData();
  }

  int get _remaining => (_dailyGoal - _consumed).clamp(0, _dailyGoal);
  double get _progress => _dailyGoal > 0 ? (_consumed / _dailyGoal).clamp(0.0, 1.0) : 0.0;
  int get _progressPercentage => (_progress * 100).round();

  Color get _progressColor {
    if (_progress >= 1.0) {
      return _consumed > _dailyGoal ? Colors.orange : Colors.green;
    } else if (_progress >= 0.7) {
      return AppColors.secondary;
    } else if (_progress >= 0.4) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String get _statusText {
    if (_consumed > _dailyGoal) {
      final excess = _consumed - _dailyGoal;
      return "+$excess over goal";
    } else if (_consumed == _dailyGoal) {
      return "Goal reached!";
    } else {
      return "$_remaining remaining";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Food Logger",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.secondary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Food Logger",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.currentChallenge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.currentChallenge!.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppColors.secondary.withOpacity(0.02),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LoggerItem(
                    label: "Daily Goal",
                    value: _dailyGoal.toString(),
                    color: AppColors.secondary,
                    icon: Icons.flag_outlined,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _LoggerItem(
                    label: "Consumed",
                    value: _consumed.toString(),
                    color: _progressColor,
                    icon: Icons.restaurant,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _LoggerItem(
                    label: _consumed > _dailyGoal ? "Excess" : "Remaining",
                    value: _consumed > _dailyGoal
                        ? (_consumed - _dailyGoal).toString()
                        : _remaining.toString(),
                    color: _consumed > _dailyGoal ? Colors.orange : Colors.green,
                    icon: _consumed > _dailyGoal ? Icons.warning_outlined : Icons.check_circle_outline,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress Section
              Column(
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: _progressColor,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Calories",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "$_progressPercentage%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _progressColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _consumed >= _dailyGoal
                            ? (_consumed > _dailyGoal ? Icons.trending_up : Icons.check_circle)
                            : Icons.trending_up,
                        size: 16,
                        color: _progressColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _progressColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Auto-sync indicator with personalization status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _hasPersonalizedGoal
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasPersonalizedGoal
                        ? Colors.blue.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasPersonalizedGoal ? Icons.calculate : Icons.warning_outlined,
                      size: 16,
                      color: _hasPersonalizedGoal
                          ? Colors.blue.shade600
                          : Colors.orange.shade600,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _hasPersonalizedGoal
                            ? "Goal calculated using Mifflin-St Jeor equation"
                            : "Using default goal - complete profile for personalized target",
                        style: TextStyle(
                          fontSize: 11,
                          color: _hasPersonalizedGoal
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoggerItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _LoggerItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}