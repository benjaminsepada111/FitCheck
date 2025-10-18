import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';

class FoodLogger extends StatefulWidget {
  final Challenge? currentChallenge;
  final VoidCallback? onCaloriesUpdated; // For notifying parent components

  const FoodLogger({
    super.key,
    this.currentChallenge,
    this.onCaloriesUpdated,
  });

  @override
  State<FoodLogger> createState() => FoodLoggerState();
}

class FoodLoggerState extends State<FoodLogger> {
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
    if (oldWidget.currentChallenge != widget.currentChallenge) {
      _loadCalorieData();
    }
  }

  Future<void> _loadCalorieData() async {
    if (!mounted) return;

    debugPrint('🔄 FoodLogger: Starting to load calorie data...');

    try {
      int goal = 2000;
      bool isPersonalized = false;

      if (widget.currentChallenge?.dailyCalorieGoal != null) {
        goal = widget.currentChallenge!.dailyCalorieGoal;
        isPersonalized = true;
      } else {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) {
          goal = calculatedGoal;
          isPersonalized = true;
        }
      }

      final today = DateTime.now();
      final consumed = widget.currentChallenge != null
          ? (await FoodLogService.getDailyCalories(today, challengeId: widget.currentChallenge!.id)).round()
          : 0;

      debugPrint('📊 FoodLogger: Fetched data - Goal: $goal, Consumed: $consumed');

      if (mounted) {
        setState(() {
          _dailyGoal = goal;
          _consumed = consumed;
          _hasPersonalizedGoal = isPersonalized;
          _isLoading = false;
        });

        debugPrint('✅ FoodLogger: State updated! New consumed: $_consumed');

        widget.onCaloriesUpdated?.call();
      }
    } catch (e) {
      debugPrint('❌ FoodLogger Error loading calorie data: $e');
      if (mounted) {
        setState(() {
          _dailyGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _consumed = 0;
          _hasPersonalizedGoal = widget.currentChallenge?.dailyCalorieGoal != null;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load calorie data. Please check your connection.'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> refreshData() async {
    debugPrint('🔄 FoodLogger: refreshData() called');
    await _loadCalorieData();
    debugPrint('✅ FoodLogger: refreshData() completed');
  }

  int get _remaining => (_dailyGoal - _consumed).clamp(0, _dailyGoal);
  double get _progress => _dailyGoal > 0 ? (_consumed / _dailyGoal).clamp(0.0, 1.0) : 0.0;
  int get _progressPercentage => (_progress * 100).round();

  Color get _progressColor => AppColors.secondary;

  String get _statusText {
    if (_consumed > _dailyGoal) {
      final excess = _consumed - _dailyGoal;
      return "+$excess over goal";
    } else if (_consumed == _dailyGoal) {
      return "Goal reached!";
    } else {
      return "";
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
              child: FitCheckLoader(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Food Logger",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                  _LoggerItem(
                    label: "Consumed",
                    value: _consumed.toString(),
                    color: AppColors.secondary,
                    icon: Icons.restaurant,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                  _LoggerItem(
                    label: _consumed > _dailyGoal ? "Excess" : "Remaining",
                    value: _consumed > _dailyGoal
                        ? (_consumed - _dailyGoal).toString()
                        : _remaining.toString(),
                    color: AppColors.secondary,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress Section
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: AppColors.secondary,
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
                          color: AppColors.secondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      minHeight: 12,
                    ),
                  ),
                  if (_statusText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              if (!_hasPersonalizedGoal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "Complete your profile for a personalized calorie goal",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
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
