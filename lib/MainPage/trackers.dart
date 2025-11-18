import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import '../app_text_styles.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
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

    // Listen to workout changes
    _workoutSubscription = WorkoutServiceV2.getWorkoutsStreamForDate(
      challengeId: widget.currentChallenge!.id,
      date: today,
    ).listen((workouts) async {
      if (!mounted) return;

      // Get user weight for calorie calculation
      final userData = await UserDataService.loadUserData();
      final userWeight = userData?.weight?.toDouble() ?? 70.0;

      int caloriesBurned = 0;
      for (var workout in workouts) {
        caloriesBurned += workout.calculateCaloriesBurned(userWeight);
      }

      setState(() {
        _caloriesBurned = caloriesBurned;
      });

      // Trigger animation
      _animationController.forward(from: 0);
    });
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
  Widget _buildCalorieOverviewCard(BuildContext context) {
    final r = context.responsive;
    final netCalories = (_currentCalories - _caloriesBurned)
        .clamp(0, double.infinity)
        .toInt();
    final consumedProgress = _calculateProgress(_currentCalories, _calorieGoal);
    final burnedProgress = _calculateProgress(_caloriesBurned, _calorieGoal);
    final isOverGoal = netCalories > _calorieGoal;

    return Container(
      margin: r.paddingSymmetric(vertical: 5, horizontal: 4),
      padding: r.paddingSymmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF06111D),
        borderRadius: BorderRadius.circular(r.size(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      size: Size(r.size(120), r.size(120)),
                      painter: _CircularProgressPainter(
                        consumedProgress: consumedProgress * _progressAnimation.value,
                        burnedProgress: burnedProgress * _progressAnimation.value,
                        isOverGoal: isOverGoal,
                        backgroundColor: Colors.grey.shade700,
                        strokeWidth: r.size(12),
                      ),
                      child: SizedBox(
                        width: r.size(120),
                        height: r.size(120),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                netCalories.toString(),
                                style: TextStyle(
                                  fontSize: r.font(36, min: 24, max: 48),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              ResponsiveGap.vertical(2),
                              Text(
                                '/ $_calorieGoal',
                                style: TextStyle(
                                  fontSize: r.font(14, min: 12, max: 18),
                                  color: Colors.grey.shade400,
                                  height: 1.0,
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
              ResponsiveGap.horizontal(20),
              // Vertical divider line
              Container(
                width: r.size(1),
                height: r.size(100),
                color: Colors.grey.shade600,
              ),
              ResponsiveGap.horizontal(20),
              // Right Side - Stats Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      context: context,
                      icon: Icons.restaurant_rounded,
                      label: 'Calories Consumed',
                      value: _currentCalories.toString(),
                      color: Colors.red,
                    ),
                    ResponsiveGap.vertical(10),
                    _buildStatRow(
                      context: context,
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final r = context.responsive;
    return Row(
      children: [
        Container(
          width: r.tapTarget(28),
          height: r.tapTarget(28),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(r.size(7)),
          ),
          child: Icon(
            icon,
            size: r.size(16),
            color: color,
          ),
        ),
        ResponsiveGap.horizontal(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: r.font(11, min: 10, max: 12),
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: r.font(22, min: 18, max: 24),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
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
    final r = context.responsive;

    // Loading state
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Calorie Overview", style: AppTextStyles.heading2),
          ResponsiveGap.vertical(16),
          Container(
            height: r.size(200),
            padding: r.padding(all: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.size(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: r.size(10),
                  offset: Offset(0, r.size(2)),
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
          Text(
            "Calorie Overview",
            style: TextStyle(
              fontSize: r.font(20, min: 18, max: 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          ResponsiveGap.vertical(16),
          Container(
            padding: r.padding(all: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(r.size(16)),
              border: Border.all(color: Colors.grey.shade300, width: r.size(1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: r.tapTarget(48),
                  color: Colors.grey.shade400,
                ),
                ResponsiveGap.vertical(16),
                Text(
                  "No Active Challenge",
                  style: TextStyle(
                    fontSize: r.font(18, min: 16, max: 22),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                ResponsiveGap.vertical(8),
                Text(
                  "Create a challenge to start tracking your progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.font(14, min: 13, max: 16),
                    color: Colors.grey.shade500,
                  ),
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
        Padding(
          padding: r.padding(bottom: 12),
          child: const Text("Calorie Overview", style: AppTextStyles.heading2),
        ),

        // Main calorie overview card with circular progress
        _buildCalorieOverviewCard(context),
      ],
    );
  }
}

// Custom painter for circular progress indicator with dual arcs
class _CircularProgressPainter extends CustomPainter {
  final double consumedProgress;
  final double burnedProgress;
  final bool isOverGoal;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.consumedProgress,
    required this.burnedProgress,
    required this.isOverGoal,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth * 0.67;

    // Arc configuration - 270 degrees with gap at top
    const startAngle = math.pi * 0.75; // Start from bottom-left
    const totalSweep = math.pi * 1.5; // 270 degrees clockwise

    // Background arc - using dark gray from theme
    final backgroundPaint = Paint()
      ..color = const Color(0xFF1A2332)
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

    // Consumed calories arc (red)
    if (consumedProgress > 0) {
      final consumedPaint = Paint()
        ..color = const Color(0xFFE94560) // Red
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final consumedSweep = totalSweep * consumedProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        consumedSweep,
        false,
        consumedPaint,
      );

      // Add dot at the end of consumed arc
      final consumedEndAngle = startAngle + consumedSweep;
      final consumedEndX = center.dx + radius * math.cos(consumedEndAngle);
      final consumedEndY = center.dy + radius * math.sin(consumedEndAngle);
      final consumedEndPoint = Offset(consumedEndX, consumedEndY);

      final consumedDotPaint = Paint()
        ..color = const Color(0xFFE94560)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(consumedEndPoint, strokeWidth / 2.2, consumedDotPaint);
    }

    // Burned calories arc (orange) - drawn on top/overlapping
    if (burnedProgress > 0) {
      final burnedPaint = Paint()
        ..color = const Color(0xFFFF8C42) // Orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final burnedSweep = totalSweep * burnedProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        burnedSweep,
        false,
        burnedPaint,
      );

      // Add dot at the end of burned arc
      final burnedEndAngle = startAngle + burnedSweep;
      final burnedEndX = center.dx + radius * math.cos(burnedEndAngle);
      final burnedEndY = center.dy + radius * math.sin(burnedEndAngle);
      final burnedEndPoint = Offset(burnedEndX, burnedEndY);

      final burnedDotPaint = Paint()
        ..color = const Color(0xFFFF8C42)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(burnedEndPoint, strokeWidth / 2.2, burnedDotPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.consumedProgress != consumedProgress ||
        oldDelegate.burnedProgress != burnedProgress ||
        oldDelegate.isOverGoal != isOverGoal;
  }
}
