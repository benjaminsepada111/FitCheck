import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/weekly_checkin_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/simple_weekly_summary_service.dart';
import 'package:capstone_project/services/calorie_calculator.dart';
import 'package:capstone_project/models/weekly_checkin.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TextEditingController _notesController = TextEditingController();
  String? _selectedFeeling;
  String? _selectedActivityChange;
  String? _weightError;
  String _userName = 'there';
  String? _currentQuote;
  WeeklySummaryData? _weeklySummary;
  bool _isLoadingSummary = true;
  WeeklyCheckIn? _latestCheckIn; // Latest check-in result after submission

  // Motivational quotes list
  static const List<Map<String, String>> _quotes = [
    {
      'quote': "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
      'author': "Aristotle"
    },
    {
      'quote': "Discipline is the bridge between goals and accomplishment.",
      'author': "Jim Rohn"
    },
    {
      'quote': "Strength does not come from physical capacity. It comes from an indomitable will.",
      'author': "Mahatma Gandhi"
    },
    {
      'quote': "Motivation is what gets you started. Habit is what keeps you going.",
      'author': "Jim Ryun"
    },
    {
      'quote': "Don't limit your challenges. Challenge your limits.",
      'author': "Jerry Dunn"
    },
    {
      'quote': "The only bad workout is the one that didn't happen.",
      'author': "Unknown"
    },
    {
      'quote': "Success isn't always about greatness. It's about consistency. Consistent hard work leads to success. Greatness will come.",
      'author': "Dwayne \"The Rock\" Johnson"
    },
    {
      'quote': "The difference between the impossible and the possible lies in a person's determination.",
      'author': "Tommy Lasorda"
    },
    {
      'quote': "Small daily improvements over time lead to stunning results.",
      'author': "Robin Sharma"
    },
    {
      'quote': "Push yourself because no one else is going to do it for you.",
      'author': "Unknown"
    },
  ];

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
    _loadNextQuote();
    _loadWeeklySummary();
  }

  /// Load the next quote in rotation (doesn't repeat until all 10 are shown)
  Future<void> _loadNextQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int quoteIndex = prefs.getInt('checkin_quote_index') ?? 0;
      
      // Get the quote at current index
      final quoteData = _quotes[quoteIndex];
      _currentQuote = "${quoteData['quote']} – ${quoteData['author']}";
      
      // Increment index for next time (cycle back to 0 after 9)
      quoteIndex = (quoteIndex + 1) % _quotes.length;
      await prefs.setInt('checkin_quote_index', quoteIndex);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Fallback to first quote if error
      final quoteData = _quotes[0];
      _currentQuote = "${quoteData['quote']} – ${quoteData['author']}";
      if (mounted) {
        setState(() {});
      }
    }
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  List<Widget> _getSlides() {
    return [
      _buildWelcomePage(),
      _buildWeeklySummaryPage(), // NEW - Weekly Summary page
      _buildWeightPage(),
      _buildFeelingPage(),
      _buildActivityPage(),
      _buildNotesPage(),
      _buildReviewPage(),
      _buildRecommendationsPage(), // Completion page
    ];
  }

  Widget _buildStepProgressIndicator() {
    const int totalSteps = 6; // Weekly Summary, Weight, Feeling, Activity, Notes, Review

    if (currentIndex == 0 || currentIndex == 7) {
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
    _notesController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String _getButtonText() {
    if (currentIndex == 0) return "LET'S START";
    if (currentIndex == 1) return "NEXT";
    if (currentIndex == 6) return "SUBMIT";
    if (currentIndex == 7) return "GOT IT!"; // Completion page

    if (currentIndex == 3 && _selectedFeeling == null) return "SKIP";
    if (currentIndex == 4 && _selectedActivityChange == null) return "SKIP";
    if (currentIndex == 5 && _notesController.text.isEmpty) return "SKIP";

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
    } else {
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

      if (currentIndex == 6) {
        // Submit check-in and generate recommendations
        await _submitCheckIn();
        shouldResetAnimation = false;
      } else if (currentIndex == 7) {
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
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        progressFeeling: _selectedFeeling,
        activityLevelChange: _selectedActivityChange,
      );

      if (mounted && success) {
        // Get the latest check-in result
        final latestCheckIn = await WeeklyCheckInService.getLatestCheckIn(widget.challenge.id);
        
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _isSubmitting = false;
            _latestCheckIn = latestCheckIn;
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
                if (currentIndex > 0 && currentIndex < 7)
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
                else if (currentIndex == 7)
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
                "Update your weight for accurate calorie calculations",
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.sentiment_satisfied_alt,
                "Progress Check",
                "Share how you're feeling about your journey",
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.fitness_center,
                "Activity Update",
                "Let us know if your activity level has changed",
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                Icons.edit_note,
                "Personal Notes",
                "Add any observations or challenges (optional)",
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
              "What is your current weight?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We use this to recalculate your daily calorie goal.",
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

  // Page 2: Feeling Selection
  Widget _buildFeelingPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How are you feeling about your progress this week?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your honest feedback helps us understand what's working.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeelingOption(
                      'great', 'Great!', Icons.sentiment_very_satisfied),
                  _buildFeelingOption('good', 'Good', Icons.sentiment_satisfied),
                  _buildFeelingOption('okay', 'Okay', Icons.sentiment_neutral),
                  _buildFeelingOption(
                      'struggling', 'Struggling', Icons.sentiment_dissatisfied),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeelingOption(String value, String label, IconData icon) {
    final isSelected = _selectedFeeling == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFeeling = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 3: Activity Level Change
  Widget _buildActivityPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Has your activity level changed this week?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This helps us adjust your calorie recommendations.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            Center(
              child: Column(
                children: [
                  _buildActivityOption(
                      'increased', 'Increased', Icons.trending_up),
                  const SizedBox(height: 12),
                  _buildActivityOption(
                      'no_change', 'No Change', Icons.trending_flat),
                  const SizedBox(height: 12),
                  _buildActivityOption(
                      'decreased', 'Decreased', Icons.trending_down),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOption(String value, String label, IconData icon) {
    final isSelected = _selectedActivityChange == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityChange = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 4: Notes
  Widget _buildNotesPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Any additional notes about your week?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Share any challenges, victories, or observations (optional).",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.08),
            TextField(
              controller: _notesController,
              maxLines: 5,
              maxLength: 150,
              style: const TextStyle(fontSize: 16),
              onTap: () {
                if (_notesController.text.isNotEmpty) {
                  _notesController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _notesController.text.length,
                  );
                }
              },
              onChanged: (value) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Your thoughts here... (optional)',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.normal,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: Colors.grey.shade300, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.secondary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 5: Review
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
            FutureBuilder<WeeklyCheckIn?>(
              future: _calculateMockCheckIn(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  );
                }
                
                final mockCheckIn = snapshot.data;
                if (mockCheckIn == null) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weight Grid (Previous and Current)
                    Row(
                      children: [
                        Expanded(
                          child: _buildWeightCard(
                            'Previous Weight',
                            '${mockCheckIn.previousWeight ?? 'N/A'}',
                            'kg',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildWeightCard(
                            'Current Weight',
                            '${_weightController.text}',
                            'kg',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // New Calorie Goal Card
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
                    
                    // Tips & Recommendations Section
                    Text(
                      'Tips & Recommendations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildPersonalizedTipsForReview(mockCheckIn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeightCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Page 6: Completion Page
  Widget _buildRecommendationsPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Spacer to push content to center
                    const Spacer(),
                    
                    // Success Animation
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

                    // Title
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
                    if (_currentQuote != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.format_quote,
                              color: AppColors.secondary.withOpacity(0.6),
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentQuote!,
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade800,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    // Spacer to push button to bottom
                    const Spacer(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Calculate mock check-in for review page
  Future<WeeklyCheckIn?> _calculateMockCheckIn() async {
    final newWeightDouble = double.tryParse(_weightController.text);
    if (newWeightDouble == null || newWeightDouble <= 0) {
      return null;
    }
    
    final weekNumber = WeeklyCheckInService.getCurrentWeekNumber(widget.challenge);
    final latestCheckIn = await WeeklyCheckInService.getLatestCheckIn(widget.challenge.id);
    final previousWeight = latestCheckIn?.currentWeight ?? (widget.challenge.originalWeight != null ? widget.challenge.originalWeight!.round() : newWeightDouble.round());
    final weightChange = (newWeightDouble - previousWeight).toDouble();
    
    final userData = await UserDataService.loadUserData();
    if (userData == null) return null;
    
    final adaptiveResult = CalorieCalculator.calculateAdaptiveAdjustment(
      userData: userData,
      currentWeight: newWeightDouble,
      previousWeight: previousWeight.toDouble(),
      currentCalorieGoal: widget.challenge.dailyCalorieGoal,
      activityLevel: widget.challenge.activityLevel,
      goal: widget.challenge.goal,
    );
    
    final newCalorieGoal = adaptiveResult['newCalorieGoal'] as int;
    final adjustment = adaptiveResult['adjustment'] as int;
    final interpretation = adaptiveResult['interpretation'] as String;
    final reason = adaptiveResult['reason'] as String;
    
    return WeeklyCheckIn(
      id: 'preview_${DateTime.now().millisecondsSinceEpoch}',
      challengeId: widget.challenge.id,
      checkInDate: DateTime.now(),
      weekNumber: weekNumber,
      currentWeight: newWeightDouble.round(),
      previousWeight: previousWeight,
      weightChange: weightChange,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      progressFeeling: _selectedFeeling,
      activityLevelChange: _selectedActivityChange,
      previousCalorieGoal: widget.challenge.dailyCalorieGoal,
      newCalorieGoal: newCalorieGoal,
      calorieAdjustment: adjustment,
      progressInterpretation: interpretation,
      adaptiveReason: reason,
      goalAdjusted: adjustment != 0,
      adjustmentNotice: null,
      weeklyCaloriesConsumed: _weeklySummary?.totalCaloriesConsumed,
      weeklyCaloriesBurned: _weeklySummary?.totalCaloriesBurned,
      createdAt: DateTime.now(),
    );
  }

  /// Build personalized tips for review page
  List<Widget> _buildPersonalizedTipsForReview(WeeklyCheckIn checkIn) {
    final tips = <Widget>[];
    
    // Get challenge goal
    final challengeGoal = widget.challenge.goal?.toLowerCase() ?? '';
    final isLoseGoal = challengeGoal.contains('lose') || challengeGoal.contains('fat') || challengeGoal.contains('deficit');
    final isMaintainGoal = challengeGoal.contains('maintain');
    final isGainGoal = challengeGoal.contains('gain') || challengeGoal.contains('muscle') || challengeGoal.contains('surplus');

    // Tip 1: Weight change progress
    if (checkIn.weightChange != null && checkIn.previousWeight != null) {
      final weightChange = checkIn.weightChange!;
      final weightChangePercent = (weightChange / checkIn.previousWeight!) * 100;
      final isExtremeChange = weightChangePercent.abs() > 2.0;
      final isModerateChange = weightChangePercent.abs() > 1.0 && weightChangePercent.abs() <= 2.0;
      
      String weightTip = '';
      
      // Handle extreme weight changes first
      if (isExtremeChange) {
        if (weightChange > 0) {
          weightTip = "Your weight increased by ${weightChange.abs().toStringAsFixed(1)}kg this week (${weightChangePercent.abs().toStringAsFixed(1)}% of body weight). Please verify your weight entry is correct.";
        } else {
          weightTip = "Your weight decreased by ${weightChange.abs().toStringAsFixed(1)}kg this week (${weightChangePercent.abs().toStringAsFixed(1)}% of body weight). Please verify your weight entry is correct.";
        }
      } else if (isLoseGoal) {
        if (weightChange <= -0.3) {
          if (weightChange >= -1.0) {
            weightTip = "Great progress! Your weight is tracking as expected. Keep following your current plan.";
          } else {
            weightTip = "You're losing weight faster than expected. Make sure you're eating enough to maintain energy levels and support your health.";
          }
        } else if (weightChange > 0.3) {
          if (isModerateChange) {
            weightTip = "Your weight increased this week. Consider checking portion sizes and tracking all meals for better accuracy.";
          } else {
            weightTip = "Your weight increased slightly this week. Consider checking portion sizes and tracking all meals for better accuracy.";
          }
        } else {
          weightTip = "Your weight stayed stable this week. For weight loss, try to maintain a consistent calorie deficit.";
        }
      } else if (isGainGoal) {
        if (weightChange >= 0.3) {
          if (weightChange <= 1.0) {
            weightTip = "Great progress! Your weight is tracking as expected. Keep following your current plan.";
          } else {
            weightTip = "You gained more than expected. Consider adjusting portion sizes to ensure steady, healthy weight gain.";
          }
        } else if (weightChange < -0.3) {
          if (isModerateChange) {
            weightTip = "Your weight decreased this week. Try increasing your calorie intake and ensure you're eating enough protein.";
          } else {
            weightTip = "Your weight decreased slightly this week. Try increasing your calorie intake and ensure you're eating enough protein.";
          }
        } else {
          weightTip = "Your weight stayed stable this week. For muscle gain, try increasing calories slightly to support growth.";
        }
      } else if (isMaintainGoal) {
        if (weightChange.abs() <= 0.3) {
          weightTip = "Perfect! Your weight is tracking as expected. Keep following your current plan.";
        } else if (weightChange > 0.3) {
          if (isModerateChange) {
            weightTip = "Your weight increased this week. Consider checking portion sizes and tracking all meals for better accuracy.";
          } else {
            weightTip = "Your weight increased slightly this week. Consider checking portion sizes and tracking all meals for better accuracy.";
          }
        } else {
          if (isModerateChange) {
            weightTip = "Your weight decreased this week. Try increasing your calorie intake slightly to maintain your current weight.";
          } else {
            weightTip = "Your weight decreased slightly this week. Try increasing your calorie intake slightly to maintain your current weight.";
          }
        }
      }

      if (weightTip.isNotEmpty) {
        tips.add(_buildTipCard(weightTip, AppColors.secondary, Icons.monitor_weight));
        tips.add(const SizedBox(height: 12));
      }
    }

    // Tip 2: Missed logging days or no logging at all
    if (_weeklySummary != null) {
      if (_weeklySummary!.totalMeals == 0 && _weeklySummary!.totalWorkouts == 0) {
        // User hasn't logged anything this week
        tips.add(_buildTipCard(
          "You haven't logged anything this week. Start logging meals and workouts to track your progress and get personalized recommendations.",
          AppColors.secondary,
          Icons.calendar_today,
        ));
        tips.add(const SizedBox(height: 12));
      } else if (_weeklySummary!.daysMissed > 0) {
        String loggingTip = '';
        if (_weeklySummary!.daysMissed == 1) {
          loggingTip = "You missed logging one day this week. Try to log every day for more accurate tracking.";
        } else {
          loggingTip = "You missed ${_weeklySummary!.daysMissed} days of logging this week. Consistent logging helps the system adjust your calorie goals accurately.";
        }
        tips.add(_buildTipCard(loggingTip, AppColors.secondary, Icons.calendar_today));
        tips.add(const SizedBox(height: 12));
      }
    }

    // Tip 3: Calorie goal adjustment status
    if (checkIn.goalAdjusted == false && checkIn.adjustmentNotice != null) {
      String notice = "Your calorie goal wasn't adjusted this week due to incomplete tracking. Log meals regularly with calories close to your target to enable automatic adjustments.";
      tips.add(_buildTipCard(notice, AppColors.secondary, Icons.info_outline));
      tips.add(const SizedBox(height: 12));
    } else if (checkIn.goalAdjusted == true && checkIn.calorieAdjustment != null && checkIn.calorieAdjustment != 0) {
      String adjustmentTip = '';
      if (checkIn.calorieAdjustment! > 0) {
        adjustmentTip = "Your calorie goal has been increased based on your progress. This adjustment helps optimize your results.";
      } else {
        adjustmentTip = "Your calorie goal has been adjusted based on your progress. Keep tracking consistently for the best results.";
      }
      tips.add(_buildTipCard(adjustmentTip, AppColors.secondary, Icons.trending_up));
      tips.add(const SizedBox(height: 12));
    }

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

}