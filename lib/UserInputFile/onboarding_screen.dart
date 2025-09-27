import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'profile.dart';
import 'genderselection.dart';
import 'weightselectorpage.dart';
import 'birthdate.dart';
import 'height.dart';
import '../LoginPages/login_page.dart';
import '../color/colors.dart';
import 'package:capstone_project/main_page.dart';
import 'goal_page.dart';
import 'activity_level.dart';
import 'privacy_consent.dart';
import 'package:capstone_project/services/user_data_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int currentIndex = 0;
  bool _isAnimating = false;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  // Validation state
  bool _isValidating = false;
  String? _validationError;

  // Required field indices (Activity Level = 5, Goal = 6)
  static const int ACTIVITY_LEVEL_INDEX = 5;
  static const int GOAL_INDEX = 6;

  final List<Widget> slides = [
    const PrivacyConsentPage(),
    const GenderSelection(),
    const BirthdatePage(),
    const WeightSelectorPage(),
    const HeightPage(),
    ValidatedActivityLevelPage(),
    ValidatedGoalPage(),
    const Profile(),
  ];

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String getButtonText() {
    if (currentIndex == 0) return "NEXT";
    if (currentIndex == slides.length - 1) return "CONFIRM";
    return "CONTINUE";
  }

  // Validation logic for required fields
  Future<bool> _validateCurrentPage() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      if (currentIndex == ACTIVITY_LEVEL_INDEX) {
        // Check if activity level is selected
        final userData = await UserDataService.loadUserData();
        if (userData?.activityLevel == null || userData!.activityLevel!.isEmpty) {
          setState(() {
            _validationError = "Please select your activity level to continue";
          });
          _showValidationError(_validationError!);
          return false;
        }
      } else if (currentIndex == GOAL_INDEX) {
        // Check if goal is selected
        final userData = await UserDataService.loadUserData();
        if (userData?.goal == null || userData!.goal!.isEmpty) {
          setState(() {
            _validationError = "Please select your fitness goal to continue";
          });
          _showValidationError(_validationError!);
          return false;
        }
      }

      return true;
    } catch (e) {
      setState(() {
        _validationError = "Error validating data. Please try again.";
      });
      _showValidationError(_validationError!);
      return false;
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Enhanced navigation with validation
  Future<void> _navigateNext() async {
    if (_isAnimating || _isValidating) return;

    setState(() {
      _isAnimating = true;
    });

    // Button press animation
    _buttonAnimationController.forward();

    try {
      // Validate required fields before proceeding
      bool isValid = await _validateCurrentPage();

      if (!isValid) {
        // Don't proceed if validation fails
        return;
      }

      if (currentIndex == slides.length - 1) {
        // Navigate to main page
        await Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              );
            },
          ),
        );
      } else {
        // Move to next page
        await _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      if (mounted) {
        _buttonAnimationController.reverse();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
          }
        });
      }
    }
  }

  Future<void> _navigateBack() async {
    if (_isAnimating || currentIndex <= 0) return;

    setState(() {
      _isAnimating = true;
      _validationError = null; // Clear validation error when going back
    });

    try {
      await _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRequiredPage = currentIndex == ACTIVITY_LEVEL_INDEX || currentIndex == GOAL_INDEX;
    bool isProcessing = _isAnimating || _isValidating;

    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Back Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (currentIndex > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28),
                      color: AppColors.secondary,
                      onPressed: isProcessing ? null : _navigateBack,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // PageView with slides
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    if (mounted) {
                      setState(() {
                        currentIndex = index;
                        _validationError = null; // Clear error when page changes
                      });
                    }
                  },
                  children: slides,
                ),
              ),

              const SizedBox(height: 20),

              // Validation Error Display
              if (_validationError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Page Indicator
              SmoothPageIndicator(
                controller: _controller,
                count: slides.length,
                effect: WormEffect(
                  activeDotColor: AppColors.secondary,
                  dotColor: AppColors.secondary.withOpacity(0.3),
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 8,
                ),
              ),

              const SizedBox(height: 30),

              // Enhanced Button with validation states
              AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                              ? SizedBox(
                            key: const ValueKey('loading'),
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textWhite.withOpacity(0.9),
                              ),
                            ),
                          )
                              : Row(
                            key: ValueKey(getButtonText()),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRequiredPage && _validationError == null)
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.textWhite,
                                  size: 18,
                                ),
                              if (isRequiredPage && _validationError == null)
                                const SizedBox(width: 8),
                              Text(
                                getButtonText(),
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Required field indicator for activity level and goal pages
              if (isRequiredPage)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.secondary.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "This field is required to continue",
                        style: TextStyle(
                          color: AppColors.secondary.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Activity Level Page with validation state
class ValidatedActivityLevelPage extends StatefulWidget {
  @override
  State<ValidatedActivityLevelPage> createState() => _ValidatedActivityLevelPageState();
}

class _ValidatedActivityLevelPageState extends State<ValidatedActivityLevelPage> with TickerProviderStateMixin {
  String? _selectedLevel = "Sedentary"; // Default to Sedentary
  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> activityLevels = [
    {
      "label": "Sedentary",
      "desc": "Little or no exercise",
      "icon": Icons.chair_outlined,
      "detail": "Office job, minimal physical activity"
    },
    {
      "label": "Light",
      "desc": "Light exercise/sports 1–3 days/week",
      "icon": Icons.directions_walk_outlined,
      "detail": "Walking, light yoga, casual sports"
    },
    {
      "label": "Moderate",
      "desc": "Moderate exercise 3–5 days/week",
      "icon": Icons.directions_run_outlined,
      "detail": "Regular gym, jogging, swimming"
    },
    {
      "label": "Active",
      "desc": "Hard exercise 6–7 days/week",
      "icon": Icons.fitness_center_outlined,
      "detail": "Daily workouts, intensive training"
    },
    {
      "label": "Very Active",
      "desc": "Hard daily exercise or physical job",
      "icon": Icons.sports_outlined,
      "detail": "Athletic training, physical labor"
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _listController.forward();
    });

    _loadSavedActivityLevel();
  }

  Future<void> _loadSavedActivityLevel() async {
    try {
      final userData = await UserDataService.loadUserData();
      if (userData?.activityLevel != null) {
        setState(() {
          _selectedLevel = userData!.activityLevel;
        });
      }
    } catch (e) {
      print('Error loading activity level: $e');
    }
  }

  Future<void> _saveActivityLevel(String level) async {
    try {
      await UserDataService.updateUserData(activityLevel: level);
      print('Activity level saved: $level');
    } catch (e) {
      print('Error saving activity level: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "How active are you?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select your typical activity level for accurate calculations",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Enhanced Activity List
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: ListView.builder(
                itemCount: activityLevels.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final item = activityLevels[index];
                  final isSelected = _selectedLevel == item["label"];

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      elevation: isSelected ? 4 : 1,
                      shadowColor: isSelected
                          ? AppColors.secondary.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() => _selectedLevel = item["label"]);
                          _saveActivityLevel(item["label"]!);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary.withOpacity(0.4)
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Activity Icon
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.secondary
                                      : AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item["icon"] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.secondary,
                                  size: 24,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["label"]!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.primary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item["desc"]!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item["detail"]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Enhanced Radio Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Transform.scale(
                                  scale: 1.1,
                                  child: Radio<String>(
                                    value: item["label"]!,
                                    groupValue: _selectedLevel,
                                    activeColor: AppColors.secondary,
                                    fillColor: MaterialStateProperty.resolveWith(
                                          (states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return AppColors.secondary;
                                        }
                                        return Colors.grey.shade400;
                                      },
                                    ),
                                    onChanged: (value) {
                                      setState(() => _selectedLevel = value);
                                      if (value != null) {
                                        _saveActivityLevel(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Goal Page with validation state
class ValidatedGoalPage extends StatefulWidget {
  @override
  State<ValidatedGoalPage> createState() => _ValidatedGoalPageState();
}

class _ValidatedGoalPageState extends State<ValidatedGoalPage> with TickerProviderStateMixin {
  String? _selectedGoal = "Maintain"; // Default to Maintain
  double _adjustment = 500;
  bool _showAdjustment = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> goals = [
    {
      "label": "Maintain",
      "desc": "Keep your current weight",
      "icon": Icons.balance,
      "detail": "Eat at maintenance calories"
    },
    {
      "label": "Fat Loss",
      "desc": "Lose weight and reduce body fat",
      "icon": Icons.trending_down,
      "detail": "Create a caloric deficit"
    },
    {
      "label": "Muscle Gain",
      "desc": "Build muscle and gain weight",
      "icon": Icons.trending_up,
      "detail": "Create a caloric surplus"
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
    });

    _loadSavedGoal();
  }

  Future<void> _loadSavedGoal() async {
    try {
      final userData = await UserDataService.loadUserData();
      if (userData?.goal != null) {
        setState(() {
          _selectedGoal = userData!.goal;
          if (userData.goalAdjustment != null) {
            _adjustment = userData.goalAdjustment!;
            _showAdjustment = true;
          }
        });
      }
    } catch (e) {
      print('Error loading goal: $e');
    }
  }

  Future<void> _saveGoal(String goal, double? adjustment) async {
    try {
      await UserDataService.updateUserData(
        goal: goal,
        goalAdjustment: adjustment,
      );
      print('Goal saved: $goal with adjustment: $adjustment');
    } catch (e) {
      print('Error saving goal: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Header Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "What is your goal?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Select your fitness objective to personalize your plan",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Goal Options
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: goals.map((goal) {
                        final isSelected = _selectedGoal == goal["label"];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            elevation: isSelected ? 4 : 1,
                            shadowColor: isSelected
                                ? AppColors.secondary.withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _selectedGoal = goal["label"];
                                  _showAdjustment = false;
                                });
                                _saveGoal(goal["label"]!, _showAdjustment ? _adjustment : null);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.secondary.withOpacity(0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.secondary.withOpacity(0.4)
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Goal Icon
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.secondary
                                            : AppColors.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        goal["icon"] as IconData,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.secondary,
                                        size: 24,
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goal["label"]!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            goal["desc"]!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            goal["detail"]!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Enhanced Radio Button
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      child: Transform.scale(
                                        scale: 1.1,
                                        child: Radio<String>(
                                          value: goal["label"]!,
                                          groupValue: _selectedGoal,
                                          activeColor: AppColors.secondary,
                                          fillColor: MaterialStateProperty.resolveWith(
                                                (states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return AppColors.secondary;
                                              }
                                              return Colors.grey.shade400;
                                            },
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGoal = value;
                                              _showAdjustment = false;
                                            });
                                            if (value != null) {
                                              _saveGoal(value, _showAdjustment ? _adjustment : null);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Optional Adjustment Section
                  if (_selectedGoal != null && _selectedGoal != "Maintain") ...[
                    const SizedBox(height: 20),

                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Optional adjustment toggle
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Customize calorie ${_selectedGoal == 'Fat Loss' ? 'deficit' : 'surplus'}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _showAdjustment
                                            ? "Adjust your daily calorie target"
                                            : "Use default settings or customize",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _showAdjustment,
                                  onChanged: (value) {
                                    setState(() => _showAdjustment = value);
                                    _saveGoal(_selectedGoal!, _showAdjustment ? _adjustment : null);
                                  },
                                  activeColor: AppColors.secondary,
                                  activeTrackColor: AppColors.secondary.withOpacity(0.3),
                                ),
                              ],
                            ),

                            // Adjustment Slider (shown conditionally)
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 300),
                              crossFadeState: _showAdjustment
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),

                                  Text(
                                    _selectedGoal == "Fat Loss"
                                        ? "Daily calorie deficit"
                                        : "Daily calorie surplus",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Enhanced Slider
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColors.secondary,
                                      inactiveTrackColor: AppColors.secondary.withOpacity(0.2),
                                      thumbColor: AppColors.secondary,
                                      overlayColor: AppColors.secondary.withOpacity(0.1),
                                      valueIndicatorColor: AppColors.secondary,
                                      trackHeight: 4,
                                    ),
                                    child: Slider(
                                      value: _adjustment,
                                      min: 200,
                                      max: 1000,
                                      divisions: 8,
                                      label: "${_adjustment.round()} kcal",
                                      onChanged: (val) {
                                        setState(() => _adjustment = val);
                                        if (_selectedGoal != null) {
                                          _saveGoal(_selectedGoal!, _adjustment);
                                        }
                                      },
                                    ),
                                  ),

                                  // Adjustment Display
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _selectedGoal == "Fat Loss"
                                              ? Icons.remove_circle_outline
                                              : Icons.add_circle_outline,
                                          color: AppColors.secondary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${_selectedGoal == 'Fat Loss' ? '-' : '+'}${_adjustment.round()} kcal/day",
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    _getAdjustmentDescription(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAdjustmentDescription() {
    if (_selectedGoal == "Fat Loss") {
      if (_adjustment <= 300) return "Mild deficit - slow, sustainable weight loss";
      if (_adjustment <= 600) return "Moderate deficit - steady weight loss";
      return "Aggressive deficit - rapid weight loss";
    } else {
      if (_adjustment <= 300) return "Lean bulk - minimal fat gain";
      if (_adjustment <= 600) return "Moderate surplus - balanced muscle gain";
      return "Aggressive bulk - rapid muscle and weight gain";
    }
  }
}