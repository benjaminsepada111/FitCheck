import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/workout_service.dart';
import '../app_text_styles.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'dart:async';
import 'dart:math' as math;

class Trackers extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(int calories) onCaloriesChanged;

  const Trackers({
    super.key,
    this.currentChallenge,
    required this.onCaloriesChanged,
  });

  @override
  State<Trackers> createState() => TrackersState();
}

class TrackersState extends State<Trackers>
    with SingleTickerProviderStateMixin {
  int _currentCalories = 0;
  int _calorieGoal = 2000;
  int _caloriesBurned = 0;
  bool _isLoading = true;

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Stream subscriptions for real-time updates
  StreamSubscription? _foodLogSubscription;
  StreamSubscription? _workoutSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadTodaysData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _foodLogSubscription?.cancel();
    _workoutSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(Trackers oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates (e.g., challenge changes)
    if (oldWidget.currentChallenge != widget.currentChallenge) {
      // Cancel old subscriptions
      _foodLogSubscription?.cancel();
      _workoutSubscription?.cancel();

      // Reload data and setup new listeners
      _loadTodaysData();
      _setupRealtimeListeners();
    }
  }

  Future<void> _loadTodaysData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final today = DateTime.now();

      // Get calorie goal (same logic as FoodLogger)
      int goal = 2000;
      if (widget.currentChallenge?.dailyCalorieGoal != null) {
        goal = widget.currentChallenge!.dailyCalorieGoal;
      } else {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        if (calculatedGoal != 2000) {
          goal = calculatedGoal;
        }
      }

      // Get calories consumed from FoodLogService
      final totalCalories = widget.currentChallenge != null
          ? (await FoodLogService.getDailyCalories(
              today,
              challengeId: widget.currentChallenge!.id,
            )).round()
          : 0;

      // Get calories burned from WorkoutService
      int caloriesBurned = 0;
      if (widget.currentChallenge != null) {
        final workouts = await WorkoutService.getWorkoutsForDate(
          widget.currentChallenge!.id,
          today,
        );

        // Get user weight for calorie calculation
        final userData = await UserDataService.loadUserData();
        final userWeight = userData?.weight?.toDouble() ?? 70.0; // Default 70kg

        for (var workout in workouts) {
          caloriesBurned += workout.calculateCaloriesBurned(userWeight);
        }
      }

      if (mounted) {
        setState(() {
          _calorieGoal = goal;
          _currentCalories = totalCalories;
          _caloriesBurned = caloriesBurned;
          _isLoading = false;
        });

        // Trigger animation
        _animationController.forward(from: 0);

        // Notify parent components
        widget.onCaloriesChanged(_currentCalories);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calorieGoal = widget.currentChallenge?.dailyCalorieGoal ?? 2000;
          _currentCalories = 0;
          _caloriesBurned = 0;
          _isLoading = false;
        });

        widget.onCaloriesChanged(0);
      }
    }
  }

  // Setup real-time listeners for food logs and workouts
  void _setupRealtimeListeners() {
    if (widget.currentChallenge == null) return;

    final today = DateTime.now();

    // Listen to food log changes
    _foodLogSubscription =
        FoodLogService.getFoodLogsStreamForDate(
          today,
          challengeId: widget.currentChallenge!.id,
        ).listen((foodLogs) {
          if (!mounted) return;

          // Calculate total calories from food logs
          double totalCalories = 0;
          for (final log in foodLogs) {
            totalCalories += log.totalCalories;
          }

          setState(() {
            _currentCalories = totalCalories.round();
          });

          // Trigger animation
          _animationController.forward(from: 0);

          // Notify parent
          widget.onCaloriesChanged(_currentCalories);
        });

    // Note: WorkoutService doesn't have a real-time stream yet
    // We'll refresh manually when workouts are added
  }

  // Public method to refresh data (can be called from parent)
  void refreshData() {
    _loadTodaysData();
  }

  double _calculateProgress(int current, int goal) {
    if (goal <= 0) return 0.0;
    return (current / goal).clamp(0.0, 1.0);
  }

  // Build the main calorie overview card with enhanced design
  Widget _buildCalorieOverviewCard() {
    final netCalories = (_currentCalories - _caloriesBurned)
        .clamp(0, double.infinity)
        .toInt();
    final progress = _calculateProgress(netCalories, _calorieGoal);
    final isOverGoal = netCalories > _calorieGoal;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3340),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          Text(
            'Calories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // Main Content Row
          Row(
            children: [
              // Left Side - Circular Progress
              Expanded(
                flex: 2,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(120, 120),
                      painter: _CircularProgressPainter(
                        progress: progress * _progressAnimation.value,
                        isOverGoal: isOverGoal,
                        backgroundColor: Colors.grey.shade700,
                        progressColor: isOverGoal ? Colors.orange : Colors.red,
                      ),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                netCalories.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Remaining',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // Right Side - Stats Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      icon: Icons.flag_rounded,
                      label: 'Base Goal',
                      value: _calorieGoal.toString(),
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.restaurant_rounded,
                      label: 'Food',
                      value: _currentCalories.toString(),
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Calories Burned',
                      value: _caloriesBurned.toString(),
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Calorie Overview", style: AppTextStyles.heading2),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: FitCheckLoader()),
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
            "Calorie Overview",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
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
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Active challenge state - New Calorie Overview Design
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text("Calorie Overview", style: AppTextStyles.heading2),
        ),

        // Main calorie overview card with circular progress
        _buildCalorieOverviewCard(),
      ],
    );
  }
}

// Custom painter for circular progress indicator
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isOverGoal;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.isOverGoal,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 12.0;

    // Arc configuration - 270 degrees with gap at top
    const startAngle = math.pi * 0.75; // Start from bottom-left
    const totalSweep = math.pi * 1.5; // 270 degrees clockwise

    // Background arc - using dark gray from theme
    final backgroundPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      backgroundPaint,
    );

    // Progress arc
    if (progress > 0) {
      // Use red color from theme
      final progressPaint = Paint()
        ..color = const Color(0xFFE94560)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final progressSweep = totalSweep * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        progressPaint,
      );

      // Add subtle dot at the end
      final endAngle = startAngle + progressSweep;
      final endX = center.dx + radius * math.cos(endAngle);
      final endY = center.dy + radius * math.sin(endAngle);
      final endPoint = Offset(endX, endY);

      final dotPaint = Paint()
        ..color = const Color(0xFFE94560)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(endPoint, strokeWidth / 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isOverGoal != isOverGoal;
  }
}
