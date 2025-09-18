import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';

class Trackers extends StatefulWidget {
  final Challenge? currentChallenge;
  final int currentCalories;
  final int currentWater;
  final Function(int calories) onCaloriesChanged;
  final Function(int water) onWaterChanged;

  const Trackers({
    super.key,
    this.currentChallenge,
    this.currentCalories = 0,
    this.currentWater = 0,
    required this.onCaloriesChanged,
    required this.onWaterChanged,
  });

  @override
  State<Trackers> createState() => _TrackersState();
}

class _TrackersState extends State<Trackers> {
  late int _currentCalories;
  late int _currentWater;

  @override
  void initState() {
    super.initState();
    _currentCalories = widget.currentCalories;
    _currentWater = widget.currentWater;
  }

  @override
  void didUpdateWidget(Trackers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCalories != widget.currentCalories) {
      _currentCalories = widget.currentCalories;
    }
    if (oldWidget.currentWater != widget.currentWater) {
      _currentWater = widget.currentWater;
    }
  }

  int _calculateStreak() {
    if (widget.currentChallenge == null) return 0;

    final now = DateTime.now();
    final startDate = widget.currentChallenge!.startDate;

    if (now.isBefore(startDate)) return 0;

    // Calculate days since start date
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

  void _showUpdateDialog(String type, int currentValue, int goalValue) {
    final TextEditingController controller = TextEditingController(
        text: currentValue.toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update $type'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: type == 'Calories' ? 'Calories consumed today' : 'Glasses of water today',
            hintText: 'Enter amount',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 0;
              if (type == 'Calories') {
                setState(() => _currentCalories = value);
                widget.onCaloriesChanged(value);
              } else {
                setState(() => _currentWater = value);
                widget.onWaterChanged(value);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTracker(String label, int current, int goal, double progress, {bool isClickable = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: isClickable && label != "Streak"
            ? () => _showUpdateDialog(label, current, goal)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular progress ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getProgressColor(progress),
                      ),
                    ),
                    if (label == "Streak")
                      Text(
                        "${current}d",
                        style: TextStyle(
                          fontSize: 12,
                          color: _getProgressColor(progress),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label == "Streak" ? "$current/$goal days" : "$current/$goal",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isClickable && label != "Streak")
              const SizedBox(height: 4),
            if (isClickable && label != "Streak")
              Text(
                "Tap to update",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Progress",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.currentChallenge!.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTracker("Calories", _currentCalories, calorieGoal, calorieProgress),
              Container(
                width: 1,
                height:80,

              ),
              _buildTracker("Water", _currentWater, waterGoal, waterProgress),
              Container(
                width: 1,
                height: 80,

              ),
              _buildTracker("Streak", currentStreak, streakGoal, streakProgress, isClickable: false),
            ],
          ),
        ),
      ],
    );
  }
}