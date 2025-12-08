import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/weekly_checkin_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/simple_weekly_summary_service.dart';
import 'package:capstone_project/services/calorie_calculator.dart';
import 'package:capstone_project/models/weekly_checkin.dart';
import 'package:capstone_project/services/weekly_trend_recommendations_service.dart';
import 'package:capstone_project/services/login_tracker_service.dart';

class WeeklyCheckInWizard extends StatefulWidget {
  final Challenge challenge;
  final VoidCallback onCheckInComplete;

  const WeeklyCheckInWizard({
    super.key,
    required this.challenge,
    required this.onCheckInComplete,
  });

  @override
  State<WeeklyCheckInWizard> createState() => _WeeklyCheckInWizardState();
}

class _WeeklyCheckInWizardState extends State<WeeklyCheckInWizard>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int currentIndex = 0;
  bool _isAnimating = false;
  bool _isSubmitting = false;

  // Form data
  final TextEditingController _weightController = TextEditingController();
  String? _weightError;
  String _userName = 'there';
  WeeklySummaryData? _weeklySummary;
  bool _isLoadingSummary = true;
  
  // Validation status for calorie adjustment
  bool _hasNotLoggedInRecently = false;
  bool _hasInsufficientCalories = false;
  bool _shouldSkipAdjustment = false;
  
  // Pre-loaded data for review page (loaded once in initState)
  WeeklyCheckIn? _cachedLatestCheckIn;
  dynamic _cachedUserData;
  bool _hasLoggedInRecently = true; // Default to true (fail-open)
  bool _isValidationDataLoaded = false;


  // Animation controllers
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadUserName();
    _loadWeeklySummary();
    _preloadValidationData(); // Pre-load data for review page
  }

  Future<void> _loadUserName() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.name != null && mounted) {
      setState(() {
        _userName = userData!.name!;
      });
    }
  }

  Future<void> _loadWeeklySummary() async {
    try {
      final weekNumber = WeeklyCheckInService.getCurrentWeekNumber(widget.challenge);
      final summary = await SimpleWeeklySummaryService.getWeeklySummary(
        challenge: widget.challenge,
        weekNumber: weekNumber,
      );
      if (mounted) {
        setState(() {
          _weeklySummary = summary;
          _isLoadingSummary = false;
        });
        // Also calculate validation status now that we have summary
        _updateValidationStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }
  
  /// Pre-load data needed for review page to avoid loading delays
  Future<void> _preloadValidationData() async {
    try {
      // Run all Firebase calls in parallel for faster loading
      final results = await Future.wait([
        WeeklyCheckInService.getLatestCheckIn(widget.challenge.id),
        UserDataService.loadUserData(),
        LoginTrackerService.hasLoggedInWithinLastNDays(
          referenceDate: DateTime.now(),
          days: 3,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => true, // Default to true on timeout
        ).catchError((_) => true), // Default to true on error
      ]);
      
      if (mounted) {
        setState(() {
          _cachedLatestCheckIn = results[0] as WeeklyCheckIn?;
          _cachedUserData = results[1];
          _hasLoggedInRecently = results[2] as bool;
          _isValidationDataLoaded = true;
        });
        _updateValidationStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasLoggedInRecently = true; // Fail-open
          _isValidationDataLoaded = true;
        });
      }
    }
  }
  
  /// Update validation status based on cached data
  void _updateValidationStatus() {
    if (_weeklySummary == null || !_isValidationDataLoaded) return;
    
    final currentCalorieGoal = widget.challenge.dailyCalorieGoal;
    final expectedWeeklyIntake = currentCalorieGoal * 7;
    final weeklyCaloriesConsumed = _weeklySummary?.totalCaloriesConsumed ?? 0;
    final calorieCompleteness = expectedWeeklyIntake > 0 
        ? (weeklyCaloriesConsumed / expectedWeeklyIntake) * 100 
        : 0.0;
    
    final hasNotLoggedIn = !_hasLoggedInRecently;
    final hasInsufficientCals = calorieCompleteness < 75.0 || weeklyCaloriesConsumed == 0;
    final shouldSkip = hasNotLoggedIn || hasInsufficientCals;
    
    if (mounted) {
      setState(() {
        _hasNotLoggedInRecently = hasNotLoggedIn;
        _hasInsufficientCalories = hasInsufficientCals;
        _shouldSkipAdjustment = shouldSkip;
      });
    }
  }

  List<Widget> _getSlides() {
    return [
      _buildWelcomePage(),
      _buildWeeklySummaryPage(),
      _buildWeightPage(),
      _buildReviewPage(),
      _buildRecommendationsPage(), // Completion page with recommendations
    ];
  }

  Widget _buildStepProgressIndicator() {
    const int totalSteps = 3; // Weekly Summary, Weight, Review

    if (currentIndex == 0 || currentIndex == 4) {
      return const SizedBox.shrink();
    }

    final progressIndex = currentIndex - 1; // Adjust for welcome page

    return Row(
      children: List.generate(totalSteps, (index) {
        final bool isCompleted = index < progressIndex;
        final bool isCurrent = index == progressIndex;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
            child: LinearProgressIndicator(
              value: isCompleted ? 1.0 : (isCurrent ? 1.0 : 0.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              minHeight: 6,
            ),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _weightController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String _getButtonText() {
    if (currentIndex == 0) return "LET'S START";
    if (currentIndex == 1) return "NEXT";
    if (currentIndex == 3) return "SUBMIT";
    if (currentIndex == 4) return "GOT IT!"; // Completion page

    return "CONTINUE";
  }

  Future<bool> _validateCurrentPage() async {
    if (currentIndex == 2) {
      // Validate weight input
      final weightText = _weightController.text.trim();
      if (weightText.isEmpty) {
        setState(() {
          _weightError = 'Please enter your current weight';
        });
        return false;
      }
      
      // Validate that it's a valid decimal number
      final weightValue = double.tryParse(weightText);
      if (weightValue == null || weightValue <= 0) {
        setState(() {
          _weightError = 'Please enter a valid weight (e.g., 50.6 or 50.60)';
        });
        return false;
      }
      
      // Clear error if valid
      setState(() {
        _weightError = null;
      });
    }
    return true;
  }

  Future<void> _navigateNext() async {
    if (_isAnimating) return;

    FocusScope.of(context).unfocus();

    setState(() => _isAnimating = true);
    _buttonAnimationController.forward();

    bool shouldResetAnimation = true;

    try {
      bool isValid = await _validateCurrentPage();
      if (!isValid) {
        if (mounted) {
          _buttonAnimationController.reverse();
          setState(() => _isAnimating = false);
        }
        shouldResetAnimation = false;
        return;
      }

      if (currentIndex == 3) {
        // Submit check-in and generate recommendations
        await _submitCheckIn();
        shouldResetAnimation = false;
      } else if (currentIndex == 4) {
        // Close wizard after viewing recommendations
        if (mounted) {
          _buttonAnimationController.reverse();
          setState(() => _isAnimating = false);
          Navigator.of(context).pop();
          widget.onCheckInComplete();
        }
        shouldResetAnimation = false;
      } else {
        // Move to next page (pages 0-5)
        await _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      if (mounted && shouldResetAnimation) {
        _buttonAnimationController.reverse();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _isAnimating = false);
        });
      }
    }
  }

  Future<void> _navigateBack() async {
    if (_isAnimating || currentIndex <= 0) return;

    FocusScope.of(context).unfocus();

    setState(() => _isAnimating = true);

    try {
      await _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _isAnimating = false);
        });
      }
    }
  }

  Future<void> _submitCheckIn() async {
    if (_isSubmitting) return;

    final newWeightDouble = double.tryParse(_weightController.text);
    if (newWeightDouble == null || newWeightDouble <= 0) {
      if (mounted) {
        _buttonAnimationController.reverse();
        setState(() {
          _weightError = 'Please enter a valid weight';
          _isAnimating = false;
        });
        _controller.jumpToPage(1);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await WeeklyCheckInService.processCheckInAndUpdateGoals(
        challenge: widget.challenge,
        newWeight: newWeightDouble, // Pass double for calculation precision
        notes: null, // Simplified - no notes in new flow
      );

      if (mounted && success) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _isSubmitting = false;
          });

          _buttonAnimationController.reverse();

          // Navigate to completion page
          await _controller.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }
      } else {
        if (mounted) {
          _buttonAnimationController.reverse();
          setState(() {
            _isAnimating = false;
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save check-in. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _buttonAnimationController.reverse();
        setState(() {
          _isAnimating = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isProcessing = _isAnimating;

    return WillPopScope(
      onWillPop: () async {
        if (isProcessing) return false;
        return true;
      },
      child: Scaffold(
        key: const ValueKey('weekly_checkin_scaffold'),
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Progress Indicator
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildStepProgressIndicator(),
                ),

                // PageView
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      if (mounted) {
                        setState(() {
                          currentIndex = index;
                        });
                      }
                    },
                    children: _getSlides(),
                  ),
                ),

                const SizedBox(height: 30),

                // Navigation Buttons
                if (currentIndex > 0 && currentIndex < 4)
                  Row(
                    children: [
                      // Back Button
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : _navigateBack,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: Text(
                            'BACK',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Next/Submit Button
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _buttonScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _buttonScaleAnimation.value,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isProcessing
                                      ? AppColors.secondary.withOpacity(0.7)
                                      : AppColors.secondary,
                                  minimumSize: const Size(double.infinity, 55),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: isProcessing ? 2 : 4,
                                  shadowColor:
                                  AppColors.secondary.withOpacity(0.3),
                                ),
                                onPressed: isProcessing ? null : _navigateNext,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: isProcessing
                                      ? const SizedBox(
                                    key: ValueKey('loading'),
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Text(
                                    key: const ValueKey('text'),
                                    _getButtonText(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                else if (currentIndex == 0)
                // First page - only Next button
                  AnimatedBuilder(
                    animation: _buttonScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _buttonScaleAnimation.value,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isProcessing
                                ? AppColors.secondary.withOpacity(0.7)
                                : AppColors.secondary,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isProcessing ? 2 : 4,
                            shadowColor: AppColors.secondary.withOpacity(0.3),
                          ),
                          onPressed: isProcessing ? null : _navigateNext,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: isProcessing
                                ? const SizedBox(
                              key: ValueKey('loading'),
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              key: const ValueKey('text'),
                              _getButtonText(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                else if (currentIndex == 4)
                  // Completion page - only "Got It" button
                    AnimatedBuilder(
                      animation: _buttonScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _buttonScaleAnimation.value,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: AppColors.secondary.withOpacity(0.3),
                            ),
                            onPressed: isProcessing ? null : _navigateNext,
                            child: const Text(
                              "GOT IT!",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== PAGE BUILDERS ====================

  // Page 0: Welcome Page
  Widget _buildWelcomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    height: 1.2,
                  ),
                  children: [
                    const TextSpan(text: "Hello "),
                    TextSpan(
                      text: _userName,
                      style: TextStyle(color: AppColors.secondary),
                    ),
                    const TextSpan(text: "!"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Time for your weekly check-in",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your answers help us keep you on track.",
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "What to expect:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoItem(
                Icons.monitor_weight_outlined,
                "Current Weight",
                "Enter your weight to track progress and adjust your calorie goals",
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.trending_up,
                "Automatic Adjustments",
                "We'll automatically adjust your daily calorie goal based on your progress",
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.lightbulb_outline,
                "Personalized Tips",
                "Get clear, actionable recommendations based on your weekly trend",
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.secondary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 1: Weekly Summary
  Widget _buildWeeklySummaryPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Week at a Glance",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Here's a summary of your activity this week",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoadingSummary)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your weekly summary...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_weeklySummary != null) ...[
              // Calories Consumed Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Total Calories Consumed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_weeklySummary!.totalCaloriesConsumed} Kcal',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Calories Burned Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_fire_department,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Total Calories Burned',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_weeklySummary!.totalCaloriesBurned} Kcal',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Additional Stats
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_weeklySummary!.totalMeals}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'meals logged',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_weeklySummary!.totalWorkouts}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'workout logged',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
            ] else ...[
              // Empty state if no data
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No data for this week yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start logging meals and workouts to see your weekly summary',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
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

  // Page 2: Weight Input
  Widget _buildWeightPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please enter your current weight for this week",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll use this to track your progress and adjust your daily calorie goal automatically.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Center(
              child: Column(
                children: [
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    onTap: () {
                      _weightController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _weightController.text.length,
                      );
                      setState(() {
                        _weightError = null;
                      });
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty && _weightError != null) {
                        setState(() {
                          _weightError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter your weight',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                      ),
                      suffixText: 'kg',
                      suffixStyle: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      errorText: _weightError,
                      errorStyle: const TextStyle(
                        fontSize: 14,
                        height: 0.8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _weightError != null
                              ? Colors.red
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _weightError != null
                              ? Colors.red
                              : AppColors.secondary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 3: Review
  Widget _buildReviewPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ready to submit?",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Review your check-in details",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            
            // Calculate and show weight grid and calorie goal
            // Using synchronous method with pre-loaded cached data
            Builder(
              builder: (context) {
                // Show loading only if validation data hasn't loaded yet
                if (!_isValidationDataLoaded || _isLoadingSummary) {
                  return const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  );
                }
                
                final mockCheckIn = _calculateMockCheckInSync();
                if (mockCheckIn == null) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Validation Warning Cards (if any validation failed)
                    if (_shouldSkipAdjustment) ...[
                      // Show warning about calorie adjustment being skipped
                      if (_hasNotLoggedInRecently) ...[
                        _buildWarningCard(
                          icon: Icons.login_outlined,
                          title: 'Consistency Tip',
                          message: "We noticed you haven't logged into the app recently. For better tracking and personalized recommendations, try to open the app regularly to stay on top of your progress.",
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Calorie Goal (unchanged) Card - white background, red border
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Calorie Goal Unchanged',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${mockCheckIn.newCalorieGoal} Kcal',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your calorie goal remains the same. Log more consistently next week for personalized adjustments.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // Normal case: Show the new calorie goal
                      if (mockCheckIn.newCalorieGoal != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.secondary,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Calorie Goal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${mockCheckIn.newCalorieGoal} Kcal',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (mockCheckIn.adaptiveReason != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            "Your calorie goal has been adjusted to help you reach your target.",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ],
                    
                    // Tips & Recommendations Section
                    if (mockCheckIn.weightTrend != null && widget.challenge.goal != null) ...[
                      Text(
                        'Tips & Recommendations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._buildTrendBasedTips(
                        mockCheckIn.weightTrend!, 
                        widget.challenge.goal!, 
                        hasInsufficientActivity: _shouldSkipAdjustment,
                        hasNotLoggedInRecently: _hasNotLoggedInRecently,
                        hasInsufficientCalories: _hasInsufficientCalories,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  

  // Page 4: Completion Page with Recommendations
  Widget _buildRecommendationsPage() {
    return FutureBuilder<WeeklyCheckIn?>(
      future: _getLatestCheckInAfterSubmit(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final checkIn = snapshot.data;
        if (checkIn == null) {
          return _buildSimpleCompletionPage();
        }
        
        // Get motivational quote
        final quote = _getMotivationalQuote();
        
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Success Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.secondary,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Check-in Complete!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Motivational Quote
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: AppColors.secondary.withOpacity(0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        quote,
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSimpleCompletionPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.secondary,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Check-in Complete!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
  
  Future<WeeklyCheckIn?> _getLatestCheckInAfterSubmit() async {
    // Wait a bit for the check-in to be saved
    await Future.delayed(const Duration(milliseconds: 500));
    return await WeeklyCheckInService.getLatestCheckIn(widget.challenge.id);
  }

  /// Calculate mock check-in for review page using simplified logic
  /// Uses pre-loaded cached data for instant loading
  WeeklyCheckIn? _calculateMockCheckInSync() {
    final newWeightDouble = double.tryParse(_weightController.text);
    if (newWeightDouble == null || newWeightDouble <= 0) {
      return null;
    }
    
    final weekNumber = WeeklyCheckInService.getCurrentWeekNumber(widget.challenge);
    // Use cached data instead of Firebase call
    final previousWeight = _cachedLatestCheckIn?.currentWeight ?? (widget.challenge.originalWeight ?? newWeightDouble);
    final weightChange = (newWeightDouble - previousWeight).toDouble();
    
    // Determine trend
    final weightTrend = CalorieCalculator.determineWeightTrend(
      currentWeight: newWeightDouble,
      previousWeight: previousWeight.toDouble(),
    );
    
    // Use cached user data
    final userData = _cachedUserData;
    if (userData == null || widget.challenge.goal == null) return null;
    
    final currentCalorieGoal = widget.challenge.dailyCalorieGoal;
    
    // Use already-calculated validation status (from _updateValidationStatus)
    final shouldSkip = _shouldSkipAdjustment;
    
    // Calculate adjustment (will be overridden if validation fails)
    int newCalorieGoal = currentCalorieGoal;
    int adjustment = 0;
    String interpretation = 'unchanged';
    String reason = 'No adjustment needed';
    
    if (!shouldSkip) {
      // Use simplified adjustment only if all validation checks pass
      final simplifiedResult = CalorieCalculator.calculateSimplifiedAdjustment(
        goal: widget.challenge.goal!,
        trend: weightTrend,
        currentCalorieGoal: currentCalorieGoal,
        currentWeight: newWeightDouble,
        previousWeight: previousWeight.toDouble(),
        userData: userData,
      );
      
      newCalorieGoal = simplifiedResult['newCalorieGoal'] as int;
      adjustment = simplifiedResult['adjustment'] as int;
      interpretation = simplifiedResult['interpretation'] as String;
      reason = simplifiedResult['reason'] as String;
    } else {
      // Set appropriate interpretation based on which check failed
      if (_hasNotLoggedInRecently) {
        interpretation = 'skipped_no_login';
        reason = 'Calorie goal kept the same. Please log in more consistently for accurate calorie adjustments.';
      } else if (_hasInsufficientCalories) {
        interpretation = 'skipped_insufficient_calories';
        reason = 'Calorie goal kept the same. Please log your calories more consistently for accurate adjustments.';
      }
    }
    
    return WeeklyCheckIn(
      id: 'preview_${DateTime.now().millisecondsSinceEpoch}',
      challengeId: widget.challenge.id,
      checkInDate: DateTime.now(),
      weekNumber: weekNumber,
      currentWeight: newWeightDouble,
      previousWeight: previousWeight,
      weightChange: weightChange,
      weightTrend: weightTrend,
      notes: null,
      progressFeeling: null,
      activityLevelChange: null,
      previousCalorieGoal: currentCalorieGoal,
      newCalorieGoal: newCalorieGoal,
      calorieAdjustment: adjustment,
      progressInterpretation: interpretation,
      adaptiveReason: reason,
      goalAdjusted: !shouldSkip && adjustment != 0,
      adjustmentNotice: null,
      weeklyCaloriesConsumed: _weeklySummary?.totalCaloriesConsumed,
      weeklyCaloriesBurned: _weeklySummary?.totalCaloriesBurned,
      createdAt: DateTime.now(),
    );
  }

  /// Build a warning card to display validation issues
  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Goal-aligned tips based on user's goal
  static const Map<String, List<String>> _goalAlignedTips = {
    'lose': [
      "Slow and steady progress is more likely to last.",
      "Staying consistent matters more than being perfect.",
      "Small daily choices add up over time.",
      "Focus on building routines you can maintain long-term.",
      "Setbacks happen—what matters is getting back on track.",
    ],
    'maintain': [
      "Keeping a steady routine helps maintain your progress.",
      "Balance and consistency are key to staying on track.",
      "Regular check-ins can help prevent unwanted changes.",
      "Sticking with familiar habits often works best.",
      "Stability comes from doing the basics well.",
    ],
    'gain': [
      "Progress takes time—stay patient and consistent.",
      "Regular routines support steady progress.",
      "Being consistent matters more than quick changes.",
      "Focus on habits you can keep doing every day.",
      "Small improvements over time lead to meaningful results.",
    ],
  };
  
  /// Habit-focused tips (general)
  static const List<String> _habitFocusedTips = [
    "Consistency matters more than doing everything perfectly.",
    "Try to follow a simple routine that fits your lifestyle.",
    "Small habits, done consistently, can make a big difference.",
    "It's okay to have off days—what matters is showing up again.",
    "Building one good habit at a time makes progress easier.",
  ];
  
  /// Get the goal type key from goal string
  String _getGoalKey(String goal) {
    final goalLower = goal.toLowerCase();
    if (goalLower.contains('lose') || goalLower.contains('fat') || goalLower.contains('deficit')) {
      return 'lose';
    } else if (goalLower.contains('gain') || goalLower.contains('muscle') || goalLower.contains('surplus')) {
      return 'gain';
    } else {
      return 'maintain';
    }
  }

  /// Build trend-based tips for review page (no weight numbers)
  /// Shows 3 tips: 1 adjustment-related + 1 goal-aligned + 1 habit-focused
  List<Widget> _buildTrendBasedTips(
    String trend, 
    String goal, {
    bool hasInsufficientActivity = false,
    bool hasNotLoggedInRecently = false,
    bool hasInsufficientCalories = false,
  }) {
    final tips = <Widget>[];
    final weekNumber = WeeklyCheckInService.getCurrentWeekNumber(widget.challenge);
    
    // Tip 1: Get adjustment-related recommendation from the trend-based service
    final recommendations = WeeklyTrendRecommendationsService.generateRecommendations(
      goal: goal,
      trend: trend,
      hasInsufficientActivity: hasInsufficientActivity,
    );
    
    // Show only the first recommendation (adjustment-related)
    if (recommendations.isNotEmpty) {
      tips.add(_buildTipCard(recommendations.first, AppColors.secondary, Icons.lightbulb_outline));
      tips.add(const SizedBox(height: 12));
    }
    
    // Tip 2: Goal-aligned tip (rotate based on week number)
    final goalKey = _getGoalKey(goal);
    final goalTips = _goalAlignedTips[goalKey] ?? _goalAlignedTips['maintain']!;
    final goalTipIndex = weekNumber % goalTips.length;
    tips.add(_buildTipCard(goalTips[goalTipIndex], AppColors.secondary, Icons.flag_outlined));
    tips.add(const SizedBox(height: 12));
    
    // Tip 3: Habit-focused tip (rotate based on week number, offset to avoid same index)
    final habitTipIndex = (weekNumber + 2) % _habitFocusedTips.length;
    tips.add(_buildTipCard(_habitFocusedTips[habitTipIndex], AppColors.secondary, Icons.repeat_outlined));
    tips.add(const SizedBox(height: 12));
    
    return tips;
  }


  Widget _buildTipCard(String message, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get a random motivational quote
  String _getMotivationalQuote() {
    final quotes = [
      "Progress, not perfection.",
      "Small steps lead to big changes.",
      "You are stronger than you think.",
      "Every journey begins with a single step.",
      "Consistency is the key to success.",
      "Your body can do it. It's your mind you need to convince.",
      "The only bad workout is the one that didn't happen.",
      "Strength doesn't come from what you can do. It comes from overcoming the things you once thought you couldn't.",
      "Take care of your body. It's the only place you have to live.",
      "Success is the sum of small efforts repeated day in and day out.",
      "You don't have to be great to start, but you have to start to be great.",
      "The pain you feel today will be the strength you feel tomorrow.",
      "Your limitation—it's only your imagination.",
      "Push yourself because no one else is going to do it for you.",
      "Great things never come from comfort zones.",
    ];
    
    // Use current date to get a consistent quote for the day
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

}