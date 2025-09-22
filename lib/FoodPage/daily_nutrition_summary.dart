import 'package:flutter/material.dart';
import 'package:capstone_project/services/food_storage_service.dart';

class DailyNutritionSummary extends StatefulWidget {
  final DateTime date;

  const DailyNutritionSummary({
    super.key,
    required this.date,
  });

  @override
  State<DailyNutritionSummary> createState() => _DailyNutritionSummaryState();
}

class _DailyNutritionSummaryState extends State<DailyNutritionSummary> {
  Map<String, double> _nutrition = {};
  bool _isLoading = true;
  final int _dailyCalorieGoal = 2000; // This could be user-configurable

  @override
  void initState() {
    super.initState();
    _loadNutritionData();
  }

  @override
  void didUpdateWidget(DailyNutritionSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      _loadNutritionData();
    }
  }

  Future<void> _loadNutritionData() async {
    setState(() => _isLoading = true);

    final nutrition = await FoodStorageService.getNutritionSummary(widget.date);

    setState(() {
      _nutrition = nutrition;
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

    final totalCalories = _nutrition['calories'] ?? 0;
    final protein = _nutrition['protein'] ?? 0;
    final carbs = _nutrition['carbs'] ?? 0;
    final fat = _nutrition['totalFat'] ?? 0;
    final progress = totalCalories / _dailyCalorieGoal;

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
                  '${totalCalories.round()}/${_dailyCalorieGoal}',
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
            const SizedBox(height: 16),

            // Macronutrients
            Row(
              children: [
                Expanded(
                  child: _MacronutrientCard(
                    label: 'Protein',
                    value: protein.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.blue,
                    icon: Icons.fitness_center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacronutrientCard(
                    label: 'Carbs',
                    value: carbs.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.orange,
                    icon: Icons.grain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacronutrientCard(
                    label: 'Fat',
                    value: fat.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.purple,
                    icon: Icons.opacity,
                  ),
                ),
              ],
            ),

            if (totalCalories > 0) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CalorieBreakdown(
                    label: 'Protein',
                    calories: (protein * 4).round(),
                    percentage: ((protein * 4) / totalCalories * 100).round(),
                    color: Colors.blue,
                  ),
                  _CalorieBreakdown(
                    label: 'Carbs',
                    calories: (carbs * 4).round(),
                    percentage: ((carbs * 4) / totalCalories * 100).round(),
                    color: Colors.orange,
                  ),
                  _CalorieBreakdown(
                    label: 'Fat',
                    calories: (fat * 9).round(),
                    percentage: ((fat * 9) / totalCalories * 100).round(),
                    color: Colors.purple,
                  ),
                ],
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

class _MacronutrientCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _MacronutrientCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '$value$unit',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieBreakdown extends StatelessWidget {
  final String label;
  final int calories;
  final int percentage;
  final Color color;

  const _CalorieBreakdown({
    required this.label,
    required this.calories,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${calories}cal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          '${percentage}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}