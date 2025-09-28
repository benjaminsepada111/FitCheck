import 'package:flutter/material.dart';
import 'package:capstone_project/services/food_log_service.dart';

class DailyCalorieSummary extends StatefulWidget {
  final DateTime date;

  const DailyCalorieSummary({
    super.key,
    required this.date,
  });

  @override
  State<DailyCalorieSummary> createState() => _DailyCalorieSummaryState();
}

class _DailyCalorieSummaryState extends State<DailyCalorieSummary> {
  double _totalCalories = 0.0;
  bool _isLoading = true;
  final int _dailyCalorieGoal = 2000; // This could be user-configurable

  @override
  void initState() {
    super.initState();
    _loadCalorieData();
  }

  @override
  void didUpdateWidget(DailyCalorieSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      _loadCalorieData();
    }
  }

  Future<void> _loadCalorieData() async {
    setState(() => _isLoading = true);

    final calories = await FoodLogService.getDailyCalories(widget.date);

    setState(() {
      _totalCalories = calories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final progress = _totalCalories / _dailyCalorieGoal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  _formatDate(widget.date),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calories Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${_totalCalories.round()}/$_dailyCalorieGoal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: progress > 1.0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1.0 ? Colors.red : Colors.green,
              ),
            ),
            if (_totalCalories > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${(_dailyCalorieGoal - _totalCalories).abs().round()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: progress > 1.0 ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      progress > 1.0 ? 'calories over goal' : 'calories remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today';
    } else if (targetDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}

