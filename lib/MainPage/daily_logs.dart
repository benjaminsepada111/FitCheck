import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/FoodPage/add_food_sheet.dart';
import 'package:capstone_project/MainPage/add_milestone_sheet.dart';
import 'package:capstone_project/WorkoutPage/add_workout_sheet.dart';

class DailyLogsPage extends StatefulWidget {
  final DateTime selectedDate;
  final Challenge? challenge;

  const DailyLogsPage({super.key, required this.selectedDate, this.challenge});

  @override
  State<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends State<DailyLogsPage> {
  int _loggedCalories = 0;
  int _calorieGoal = 2000;
  int _caloriesBurned = 0;
  Map<String, List<FoodEntry>> _foodEntriesByMeal = {};
  List<Milestone> _milestones = [];
  List<Workout> _workouts = [];
  bool _isLoading = true;

  // Page controller for workout carousel
  PageController? _workoutPageController;
  int _currentWorkoutPage = 0;

  bool get _canEditThisDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    // Can only edit dates BEFORE today (yesterday and earlier)
    return selectedDay.isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  @override
  void dispose() {
    _workoutPageController?.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);

    try {
      // Get calorie goal
      int goal = 2000;
      if (widget.challenge?.dailyCalorieGoal != null) {
        goal = widget.challenge!.dailyCalorieGoal;
      } else {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) {
          goal = calculatedGoal;
        }
      }

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
      // Load workouts for the selected date
      final workoutsForDate = widget.challenge != null
          ? await WorkoutServiceV2.getWorkoutsForDate(
        challengeId: widget.challenge!.id,
        date: widget.selectedDate,
      )
          : <Workout>[];

      // Calculate calories burned from workouts
      int caloriesBurned = 0;
      if (widget.challenge != null && workoutsForDate.isNotEmpty) {
        final userData = await UserDataService.loadUserData();
        final userWeight = userData?.weight?.toDouble() ?? 70.0;

        for (var workout in workoutsForDate) {
          caloriesBurned += workout.calculateCaloriesBurned(userWeight);
        }
      }

      setState(() {
        _calorieGoal = goal;
        _loggedCalories = totalCalories;
        _caloriesBurned = caloriesBurned;
        _foodEntriesByMeal = mealEntries;
        _milestones = dateMilestones;
        _workouts = workoutsForDate;
        _isLoading = false;

        // Initialize page controller for workouts if there are any
        if (workoutsForDate.isNotEmpty) {
          _workoutPageController?.dispose();
          _workoutPageController = PageController(viewportFraction: 0.90);
          _currentWorkoutPage = 0;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load daily data'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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

  // Show Add Food Sheet (you need to import your AddFoodSheet)
  void _showAddFoodSheet(String mealType) async {
    if (widget.challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active challenge. Please start a challenge first.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFoodSheet(
        mealName: mealType,
        challengeId: widget.challenge!.id,
        selectedDate: widget.selectedDate, // Pass the selected date
        onFoodAdded: (foodName, calories, {grams, imageUrl, servingSize, unit}) async {
          final foodEntry = FoodEntry(
            id: 'food_${DateTime.now().millisecondsSinceEpoch}',
            fdcId: DateTime.now().millisecondsSinceEpoch,
            foodName: foodName,
            servingSize: servingSize ?? grams ?? 100,
            servingUnit: unit ?? 'g',
            caloriesPer100g: calories / ((servingSize ?? grams ?? 100) / 100),
            imageUrl: imageUrl,
          );

          await FoodLogService.addFoodEntry(
            widget.selectedDate, // Use selected date
            mealType,
            foodEntry,
            challengeId: widget.challenge!.id,
          );

          _loadDailyData();
        },
      ),
    );
  }

// Show Add Workout Sheet
  void _showAddWorkoutSheet() async {
    if (widget.challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active challenge. Please start a challenge first.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWorkoutSheet(
        currentChallenge: widget.challenge!,
        selectedDate: widget.selectedDate, // Pass the selected date
        onWorkoutAdded: () {
          _loadDailyData();
        },
      ),
    );
  }

// Show Add Milestone Sheet
  void _showAddMilestoneSheet() async {
    if (widget.challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active challenge. Please start a challenge first.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMilestoneSheet(
        selectedDate: widget.selectedDate, // Pass the selected date
        challengeId: widget.challenge!.id,
        onSave: (milestone, imageFile) async {
          await MilestoneService.saveMilestone(
            milestone,
            imageFile: imageFile,
            challengeId: widget.challenge!.id,
          );
          _loadDailyData();
        },
      ),
    );
  }

// Quick Add Menu
  void _showQuickAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Entry for ${_formatDate(widget.selectedDate)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Add Food
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.restaurant, color: AppColors.secondary.shade700),
              ),
              title: const Text('Add Food'),
              subtitle: const Text('Log your meal'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showMealTypeSelector();
              },
            ),

            // Add Workout
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fitness_center, color: AppColors.secondary.shade700),
              ),
              title: const Text('Add Workout'),
              subtitle: const Text('Log your exercise'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showAddWorkoutSheet();
              },
            ),

            // Add Milestone
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: AppColors.secondary.shade700),
              ),
              title: const Text('Add Progress Photo'),
              subtitle: const Text('Capture your milestone'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showAddMilestoneSheet();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

// Show meal type selector for food logging
  void _showMealTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Meal Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _buildMealTypeOption('Breakfast', Icons.wb_sunny),
            _buildMealTypeOption('Lunch', Icons.lunch_dining),
            _buildMealTypeOption('Dinner', Icons.dinner_dining),
            _buildMealTypeOption('Snack', Icons.fastfood),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

// Build meal type option widget
  Widget _buildMealTypeOption(String mealType, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.secondary),
      ),
      title: Text(mealType),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        _showAddFoodSheet(mealType);
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Log',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              _formatDate(widget.selectedDate),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: FitCheckLoader())
          : RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _loadDailyData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Daily Summary
              _buildDailySummary(),

              const SizedBox(height: 24),

              // Progress Photo Section
              if (_milestones.isNotEmpty) _buildProgressPhotos(),

              // Workout Section
              if (_workouts.isNotEmpty) _buildWorkoutSection(),

              // Food Logs Section
              _buildFoodLogs(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

      floatingActionButton: _canEditThisDate && widget.challenge != null
          ? FloatingActionButton.extended(
        onPressed: _showQuickAddMenu,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      )
          : null,
    );
  }

  Widget _buildDailySummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF06111D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.track_changes_rounded,
                  label: 'Goal',
                  value: _calorieGoal.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.restaurant_rounded,
                  label: 'Consumed',
                  value: _loggedCalories.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Burned',
                  value: _caloriesBurned.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    // Determine color based on label
    Color iconColor;
    if (label == 'Goal') {
      iconColor = Colors.blue;
    } else if (label == 'Consumed') {
      iconColor = Colors.red;
    } else {
      iconColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_milestones.length} ${_milestones.length == 1 ? 'photo' : 'photos'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._milestones.map((milestone) => _buildMilestoneCard(milestone)),
        ],
      ),
    );
  }

  Widget _buildWorkoutSection() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Workouts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_workouts.length} ${_workouts.length == 1 ? 'workout' : 'workouts'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal workout carousel
          SizedBox(
            height: 250,
            child: PageView.builder(
              controller: _workoutPageController,
              itemCount: _workouts.length,
              padEnds: false,
              onPageChanged: (page) {
                setState(() {
                  _currentWorkoutPage = page;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 6,
                    right: index == _workouts.length - 1 ? 16 : 6,
                  ),
                  child: _buildWorkoutCard(_workouts[index]),
                );
              },
            ),
          ),
          // Page Indicators
          if (_workouts.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _workouts.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentWorkoutPage == index ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentWorkoutPage == index
                        ? AppColors.secondary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// Replace your _buildWorkoutCard method with this vertical layout version:

  Widget _buildWorkoutCard(Workout workout) {
    return GestureDetector(
      onTap: () => _showWorkoutDetail(workout),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF06111D),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image at the top
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: _buildWorkoutImage(workout, height: 140),
              ),
            ),

            // Details below image
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type, Time, and Stats Row
                  Row(
                    children: [
                      Icon(
                        workout.isCardio
                            ? Icons.directions_run
                            : Icons.fitness_center,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(workout.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        workout.isCardio ? 'Cardio' : 'Strength',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Add duration for cardio or sets/reps for strength inline
                      if (workout.isCardio && workout.durationMinutes != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '|',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${workout.durationMinutes} min',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (workout.isStrength &&
                          workout.sets != null &&
                          workout.reps != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '|',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${workout.sets} sets • ${workout.reps} reps',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Exercise Name
                  Text(
                    workout.exerciseName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Updated workout detail dialog to match the dark theme:

  void _showWorkoutDetail(Workout workout) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF06111D),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: _buildWorkoutImage(workout, height: 180),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise Name
                      Text(
                        workout.exerciseName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: workout.isCardio
                              ? Colors.blue.withValues(alpha: 0.2)
                              : AppColors.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              workout.isCardio
                                  ? Icons.directions_run_rounded
                                  : Icons.fitness_center_rounded,
                              size: 16,
                              color: workout.isCardio
                                  ? Colors.blue.shade300
                                  : AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              workout.isCardio ? 'Cardio' : 'Strength Training',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: workout.isCardio
                                    ? Colors.blue.shade300
                                    : AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Stats Row - Show appropriate stats based on workout type
                      if (workout.isStrength) ...[
                        if (workout.sets != null && workout.reps != null)
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                  Icons.repeat_rounded,
                                  'Sets',
                                  workout.sets.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDetailItem(
                                  Icons.numbers_rounded,
                                  'Reps',
                                  workout.reps.toString(),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No sets/reps information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else if (workout.isCardio) ...[
                        if (workout.durationMinutes != null)
                          _buildDetailItem(
                            Icons.schedule_rounded,
                            'Duration',
                            '${workout.durationMinutes} min',
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No duration information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // Notes Section
                      if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade800),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notes_rounded,
                                    size: 18,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Notes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                workout.notes!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Timestamp
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(workout.timestamp),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Close Button
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
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

// Updated detail item for dark theme:

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(Milestone milestone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Photo
          Container(
            width: 140,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMilestoneImage(milestone),
            ),
          ),
          const SizedBox(width: 16),
          // Notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  milestone.notes ?? 'No notes added',
                  style: TextStyle(
                    fontSize: 14,
                    color: milestone.notes != null
                        ? Colors.grey.shade800
                        : Colors.grey.shade400,
                    height: 1.6,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(milestone.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalEntries ${totalEntries == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Build each meal section
          _buildMealSection('Breakfast'),
          const SizedBox(height: 20),
          _buildMealSection('Lunch'),
          const SizedBox(height: 20),
          _buildMealSection('Dinner'),
          const SizedBox(height: 20),
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

    IconData mealIcon;
    switch (mealType) {
      case 'Breakfast':
        mealIcon = Icons.wb_sunny_rounded;
        break;
      case 'Lunch':
        mealIcon = Icons.lunch_dining_rounded;
        break;
      case 'Dinner':
        mealIcon = Icons.dinner_dining_rounded;
        break;
      default:
        mealIcon = Icons.fastfood_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                mealIcon,
                size: 20,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              mealType,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.local_fire_department_rounded,
                size: 14,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                '$totalCalories cal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'No entries',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Food image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildFoodImage(entry, width: 70, height: 70),
            ),
            const SizedBox(width: 14),
            // Food details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.foodName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entry.servingSize > 0) ...[
                        Icon(
                          Icons.scale_rounded,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.servingSize.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.totalCalories.round()} cal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.totalCalories.round()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.2,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    top: Radius.circular(24),
                  ),
                  child: _buildFoodImage(
                    entry,
                    width: double.infinity,
                    height: 250,
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.foodName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFoodDetailItem(
                              Icons.local_fire_department_rounded,
                              'Calories',
                              '${entry.totalCalories.round()}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFoodDetailItem(
                              Icons.scale_rounded,
                              'Serving',
                              '${entry.servingSize.toStringAsFixed(0)}g',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Nutritional Info',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${entry.caloriesPer100g.toStringAsFixed(1)} cal per 100g',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build food image
  Widget _buildFoodImage(
      FoodEntry entry, {
        required double width,
        required double height,
      }) {
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
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
                strokeWidth: 3,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFoodImagePlaceholder(width, height);
        },
      );
    }

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

    return _buildFoodImagePlaceholder(width, height);
  }

  Widget _buildFoodImagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.6),
            AppColors.secondary.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: height > 100 ? 64 : 28,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  /// Helper method to build workout image
  Widget _buildWorkoutImage(Workout workout, {required double height}) {
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
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
                strokeWidth: 3,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildWorkoutImagePlaceholder(height);
        },
      );
    }

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

    return _buildWorkoutImagePlaceholder(height);
  }

  Widget _buildWorkoutImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF121C29).withValues(alpha: 0.7),
            const Color(0xFF121C29).withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Icon(
        Icons.fitness_center_rounded,
        size: height > 150 ? 64 : 40,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  /// Helper method to build milestone image
  Widget _buildMilestoneImage(Milestone milestone) {
    if (milestone.imageUrl != null && milestone.imageUrl!.isNotEmpty) {
      return Image.network(
        milestone.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.secondary,
                strokeWidth: 3,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildMilestoneImagePlaceholder();
        },
      );
    }

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

    return _buildMilestoneImagePlaceholder();
  }

  Widget _buildMilestoneImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.7),
            AppColors.secondary.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}