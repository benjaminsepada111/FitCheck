import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';

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


      if (mounted) {
        setState(() {
          _dailyGoal = goal;
          _consumed = consumed;
          _hasPersonalizedGoal = isPersonalized;
          _isLoading = false;
        });


        widget.onCaloriesUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailyGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _consumed = 0;
          _hasPersonalizedGoal = widget.currentChallenge?.dailyCalorieGoal != null;
          _isLoading = false;
        });

        final r = context.responsive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load calorie data. Please check your connection.'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.size(8))),
          ),
        );
      }
    }
  }

  Future<void> refreshData() async {
    await _loadCalorieData();
  }

  int get _remaining => (_dailyGoal - _consumed).clamp(0, _dailyGoal);
  double get _progress => _dailyGoal > 0 ? (_consumed / _dailyGoal).clamp(0.0, 1.0) : 0.0;
  int get _progressPercentage => (_progress * 100).round();

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
    final r = context.responsive;

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Food Logger",
            style: TextStyle(fontSize: r.font(18, min: 16, max: 22), fontWeight: FontWeight.bold),
          ),
          ResponsiveGap(12),
          Container(
            height: r.size(140),
            padding: EdgeInsets.all(r.size(16)),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.secondary),
              borderRadius: BorderRadius.circular(r.size(16)),
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
        Text(
          "Food Logger",
          style: TextStyle(fontSize: r.font(18, min: 16, max: 22), fontWeight: FontWeight.bold),
        ),
        ResponsiveGap(12),
        Container(
          padding: EdgeInsets.all(r.size(20)),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(r.size(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: r.size(8),
                offset: Offset(0, r.size(2)),
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
                    width: r.size(1),
                    height: r.size(40),
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                  _LoggerItem(
                    label: "Consumed",
                    value: _consumed.toString(),
                    color: AppColors.secondary,
                    icon: Icons.restaurant,
                  ),
                  Container(
                    width: r.size(1),
                    height: r.size(40),
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

              ResponsiveGap(24),

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
                            size: r.size(18),
                            color: AppColors.secondary,
                          ),
                          ResponsiveGap.horizontal(6),
                          Text(
                            "Calories",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: r.font(16, min: 14, max: 18),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "$_progressPercentage%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          fontSize: r.font(16, min: 14, max: 18),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveGap(8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.size(10)),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      minHeight: r.size(12),
                    ),
                  ),
                  if (_statusText.isNotEmpty) ...[
                    ResponsiveGap(8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: r.font(14, min: 12, max: 16),
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),

              ResponsiveGap(16),

              if (!_hasPersonalizedGoal)
                Container(
                  padding: r.paddingSymmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.size(8)),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: r.size(16),
                        color: AppColors.secondary,
                      ),
                      ResponsiveGap.horizontal(6),
                      Flexible(
                        child: Text(
                          "Complete your profile for a personalized calorie goal",
                          style: TextStyle(
                            fontSize: r.font(11, min: 10, max: 13),
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
    final r = context.responsive;
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: r.size(20),
            color: color,
          ),
          ResponsiveGap(6),
          Text(
            label,
            style: TextStyle(
              fontSize: r.font(12, min: 10, max: 14),
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          ResponsiveGap(4),
          Text(
            value,
            style: TextStyle(
              fontSize: r.font(22, min: 18, max: 26),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
