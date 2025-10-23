import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:capstone_project/widgets/fitcheck_loader.dart';

class DailyLogsPage extends StatefulWidget {
  final DateTime selectedDate;
  final Challenge? challenge;

  const DailyLogsPage({super.key, required this.selectedDate, this.challenge});

  @override
  State<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends State<DailyLogsPage> {
  int _loggedCalories = 0;
  Map<String, List<FoodEntry>> _foodEntriesByMeal = {};
  List<Milestone> _milestones = [];
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);

    try {
      // Load food logs for the selected date
      final foodLogs = widget.challenge != null
          ? await FoodLogService.getFoodLogsForDate(
              widget.selectedDate,
              challengeId: widget.challenge!.id,
            )
          : <FoodLog>[];

      // Calculate total calories and organize by meal
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

          // Log each entry
          for (var entry in log.entries) {}
        }
      }

      // Load milestones for the selected date
      final allMilestones = widget.challenge != null
          ? await MilestoneService.getAllMilestones(
              challengeId: widget.challenge!.id,
            )
          : <Milestone>[];
      final dateMilestones = allMilestones
          .where((m) => _isSameDate(m.date, widget.selectedDate))
          .toList();

      // Load workouts for the selected date
      final workoutsForDate = widget.challenge != null
          ? await WorkoutService.getWorkoutsForDate(
              widget.challenge!.id,
              widget.selectedDate,
            )
          : <Workout>[];

      setState(() {
        _loggedCalories = totalCalories;
        _foodEntriesByMeal = mealEntries;
        _milestones = dateMilestones;
        _workouts = workoutsForDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load daily data'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      ),
      body: _isLoading
          ? const Center(child: FitCheckLoader())
          : RefreshIndicator(
              onRefresh: _loadDailyData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Summary with circular progress
                    _buildDailySummary(),

                    const SizedBox(height: 24),

                    // Progress Photo Section
                    if (_milestones.isNotEmpty) _buildProgressPhotos(),

                    // Workout Section
                    if (_workouts.isNotEmpty) _buildWorkoutSection(),

                    // Food Logs Section
                    _buildFoodLogs(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDailySummary() {
    // Calculate total food entries logged (not meal types)
    final mealsLogged = _foodEntriesByMeal.values.fold<int>(
      0,
      (sum, entries) => sum + entries.length,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Workouts',
                  value: _workouts.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Calories',
                  value: _loggedCalories.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Meals',
                  value: mealsLogged.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPhotos() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_milestones.length} ${_milestones.length == 1 ? 'photo' : 'photos'}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display all milestones for this date
          ..._milestones.map((milestone) => _buildMilestoneCard(milestone)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWorkoutSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Workouts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_workouts.length} ${_workouts.length == 1 ? 'workout' : 'workouts'}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display workout cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _workouts
                .map((workout) => _buildWorkoutCard(workout))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    return GestureDetector(
      onTap: () => _showWorkoutDetail(workout),
      child: Container(
        width:
            (MediaQuery.of(context).size.width - 44) /
            2, // Half width minus padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: _buildWorkoutImage(workout, height: 120),
            ),
            // Exercise details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.exerciseName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${workout.sets} sets',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.numbers,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${workout.reps} reps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }

  void _showWorkoutDetail(Workout workout) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildWorkoutImage(workout, height: 250),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.exerciseName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              Icons.repeat,
                              'Sets',
                              workout.sets.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailItem(
                              Icons.numbers,
                              'Reps',
                              workout.reps.toString(),
                            ),
                          ),
                        ],
                      ),
                      if (workout.notes != null &&
                          workout.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          workout.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(workout.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(Milestone milestone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Photo
          Container(
            width: 180,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  milestone.imagePath != null && milestone.imagePath!.isNotEmpty
                  ? Image.file(
                      File(milestone.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
          ),
          const SizedBox(width: 16),
          // Notes
          Expanded(
            child: Container(
              height: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        milestone.notes ?? 'No notes added',
                        style: TextStyle(
                          fontSize: 14,
                          color: milestone.notes != null
                              ? Colors.grey.shade800
                              : Colors.grey.shade400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(milestone.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withOpacity(0.7),
            AppColors.secondary.withOpacity(0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Widget _buildFoodLogs() {
    final totalEntries = _foodEntriesByMeal.values.fold<int>(
      0,
      (sum, entries) => sum + entries.length,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Food Logs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$totalEntries ${totalEntries == 1 ? 'entry' : 'entries'}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Build each meal section
          _buildMealSection('Breakfast'),
          const SizedBox(height: 16),
          _buildMealSection('Lunch'),
          const SizedBox(height: 16),
          _buildMealSection('Dinner'),
          const SizedBox(height: 16),
          _buildMealSection('Snack'),
        ],
      ),
    );
  }

  Widget _buildMealSection(String mealType) {
    final entries = _foodEntriesByMeal[mealType] ?? [];
    final totalCalories = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.totalCalories.round(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              mealType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (entries.isNotEmpty)
              Text(
                '$totalCalories cal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'No entries',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ...entries.map((entry) => _buildFoodEntry(entry)),
      ],
    );
  }

  Widget _buildFoodEntry(FoodEntry entry) {
    return GestureDetector(
      onTap: () => _showFoodDetail(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Food image or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildFoodImage(entry, width: 60, height: 60),
            ),
            const SizedBox(width: 12),
            // Food details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.foodName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (entry.servingSize > 0) ...[
                        Icon(
                          Icons.scale,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.servingSize.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                      Icon(
                        Icons.local_fire_department,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.totalCalories.round()} cal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Calorie badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.totalCalories.round()}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFoodDetail(FoodEntry entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildFoodImage(
                    entry,
                    width: double.infinity,
                    height: 250,
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.foodName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFoodDetailItem(
                              Icons.local_fire_department,
                              'Calories',
                              '${entry.totalCalories.round()}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFoodDetailItem(
                              Icons.scale,
                              'Serving',
                              '${entry.servingSize.toStringAsFixed(0)}g',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nutritional Info',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${entry.caloriesPer100g.toStringAsFixed(1)} cal per 100g',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// Helper method to build food image from either imageUrl (Cloud Storage) or imageBase64 (legacy)
  Widget _buildFoodImage(
    FoodEntry entry, {
    required double width,
    required double height,
  }) {
    // Priority 1: Use imageUrl from Cloud Storage (new method)
    if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) {
      return Image.network(
        entry.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFoodImagePlaceholder(width, height);
        },
      );
    }

    // Priority 2: Use imageBase64 (legacy/backward compatibility)
    if (entry.imageBase64 != null && entry.imageBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(entry.imageBase64!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFoodImagePlaceholder(width, height);
          },
        );
      } catch (e) {
        return _buildFoodImagePlaceholder(width, height);
      }
    }

    // No image available - show placeholder
    return _buildFoodImagePlaceholder(width, height);
  }

  /// Build placeholder for food images
  Widget _buildFoodImagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withOpacity(0.6),
            AppColors.secondary.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: height > 100 ? 64 : 24,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  /// Helper method to build workout image from either imageUrl (Cloud Storage) or imageBase64 (legacy)
  Widget _buildWorkoutImage(Workout workout, {required double height}) {
    // Priority 1: Use imageUrl from Cloud Storage (new method)
    if (workout.imageUrl != null && workout.imageUrl!.isNotEmpty) {
      return Image.network(
        workout.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildWorkoutImagePlaceholder(height);
        },
      );
    }

    // Priority 2: Use imageBase64 (legacy/backward compatibility)
    if (workout.imageBase64 != null && workout.imageBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(workout.imageBase64!),
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildWorkoutImagePlaceholder(height);
          },
        );
      } catch (e) {
        return _buildWorkoutImagePlaceholder(height);
      }
    }

    // No image available - show placeholder
    return _buildWorkoutImagePlaceholder(height);
  }

  /// Build placeholder for workout images
  Widget _buildWorkoutImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withOpacity(0.7),
            AppColors.secondary.withOpacity(0.4),
          ],
        ),
      ),
      child: Icon(
        Icons.fitness_center,
        size: height > 150 ? 64 : 40,
        color: Colors.white.withOpacity(0.8),
      ),
    );
  }

  /// Helper method to build milestone image from either imageUrl (Cloud Storage) or imagePath (local file)
  Widget _buildMilestoneImage(Milestone milestone) {
    // Priority 1: Use imageUrl from Cloud Storage (new method)
    if (milestone.imageUrl != null && milestone.imageUrl!.isNotEmpty) {
      return Image.network(
        milestone.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildMilestoneImagePlaceholder();
        },
      );
    }

    // Priority 2: Use imagePath (local file/legacy)
    if (milestone.imagePath != null && milestone.imagePath!.isNotEmpty) {
      try {
        return Image.file(
          File(milestone.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildMilestoneImagePlaceholder();
          },
        );
      } catch (e) {
        return _buildMilestoneImagePlaceholder();
      }
    }

    // No image available - show placeholder
    return _buildMilestoneImagePlaceholder();
  }

  /// Build placeholder for milestone images
  Widget _buildMilestoneImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withOpacity(0.7),
            AppColors.secondary.withOpacity(0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}
