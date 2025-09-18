// Create file: lib/pages/daily_logs.dart

import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';

class DailyLogsPage extends StatefulWidget {
  final DateTime selectedDate;
  final Challenge? challenge;

  const DailyLogsPage({
    super.key,
    required this.selectedDate,
    this.challenge,
  });

  @override
  State<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends State<DailyLogsPage> {
  // Sample data - replace with actual data storage
  int _loggedCalories = 0;
  int _loggedWater = 0;
  List<Map<String, dynamic>> _foodEntries = [];
  String _notes = '';
  bool _isToday = false;

  @override
  void initState() {
    super.initState();
    _isToday = _isSameDate(widget.selectedDate, DateTime.now());
    _loadDailyData();
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _loadDailyData() {
    // TODO: Load actual data from storage/database for the selected date
    // For now, using sample data
    setState(() {
      _loggedCalories = 1250; // Sample data
      _loggedWater = 4; // Sample data
      _foodEntries = [
        {'name': 'Oatmeal with berries', 'calories': 320, 'time': '8:00 AM'},
        {'name': 'Grilled chicken salad', 'calories': 450, 'time': '12:30 PM'},
        {'name': 'Apple', 'calories': 80, 'time': '3:15 PM'},
        {'name': 'Salmon with rice', 'calories': 400, 'time': '7:00 PM'},
      ];
      _notes = 'Felt energetic today. Went for a 30-minute walk after lunch.';
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  double _getCalorieProgress() {
    if (widget.challenge == null) return 0.0;
    return (_loggedCalories / widget.challenge!.dailyCalorieGoal).clamp(0.0, 1.0);
  }

  double _getWaterProgress() {
    if (widget.challenge == null) return 0.0;
    return (_loggedWater / widget.challenge!.dailyWaterGoal).clamp(0.0, 1.0);
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.8) return AppColors.secondary;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Log',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatDate(widget.selectedDate),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_isToday)
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.secondary),
              onPressed: () {
                // TODO: Navigate to edit mode
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit mode - Coming soon!')),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Challenge Info Card (if challenge exists)
            if (widget.challenge != null) _buildChallengeCard(),

            const SizedBox(height: 16),

            // Progress Summary
            _buildProgressSummary(),

            const SizedBox(height: 20),

            // Food Entries
            _buildFoodEntries(),

            const SizedBox(height: 20),

            // Daily Notes
            _buildDailyNotes(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.track_changes,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.challenge!.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  'Daily Goals: ${widget.challenge!.dailyCalorieGoal} cal • ${widget.challenge!.dailyWaterGoal} glasses',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    final calorieProgress = _getCalorieProgress();
    final waterProgress = _getWaterProgress();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Calories Progress
          _buildProgressItem(
            'Calories',
            _loggedCalories,
            widget.challenge?.dailyCalorieGoal ?? 2000,
            'kcal',
            calorieProgress,
          ),

          const SizedBox(height: 16),

          // Water Progress
          _buildProgressItem(
            'Water',
            _loggedWater,
            widget.challenge?.dailyWaterGoal ?? 8,
            'glasses',
            waterProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int current, int goal, String unit, double progress) {
    final progressColor = _getProgressColor(progress);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$current/$goal $unit',
              style: TextStyle(
                fontSize: 14,
                color: progressColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodEntries() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Food Entries',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_isToday)
                TextButton.icon(
                  onPressed: () {
                    // TODO: Add food entry
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add food - Coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_foodEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No food entries for this day',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _foodEntries.map((entry) => _buildFoodEntry(entry)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodEntry(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.restaurant,
              color: AppColors.secondary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  entry['time'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry['calories']} cal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyNotes() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_isToday)
                TextButton.icon(
                  onPressed: () {
                    // TODO: Edit notes
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit notes - Coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.note_add,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No notes for this day',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _notes,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade800,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}