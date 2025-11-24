import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/weekly_checkin_service.dart';
import 'package:capstone_project/services/user_data_service.dart';

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

  // Form data
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedFeeling;
  String? _selectedActivityChange;
  String? _weightError;
  String _userName = 'there'; // Default fallback name

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

    // Load user's name
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.name != null && mounted) {
      setState(() {
        _userName = userData!.name!;
      });
    }
  }

  List<Widget> _getSlides() {
    return [
      _buildWelcomePage(),
      _buildWeightPage(),
      _buildFeelingPage(),
      _buildActivityPage(),
      _buildNotesPage(),
      _buildReviewPage(),
    ];
  }

  Widget _buildStepProgressIndicator() {
    const int totalSteps = 5; // 5 steps (pages 1-5, excluding welcome page 0)

    // Don't show progress bar on welcome page
    if (currentIndex == 0) {
      return const SizedBox.shrink();
    }

    // Adjust index for progress (welcome page doesn't count)
    final progressIndex = currentIndex - 1;

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
    if (currentIndex == 5) return "SUBMIT";

    // Pages 2, 3, 4 (Feeling, Activity, Notes) - show SKIP if nothing selected
    if (currentIndex == 2 && _selectedFeeling == null) return "SKIP";
    if (currentIndex == 3 && _selectedActivityChange == null) return "SKIP";
    if (currentIndex == 4 && _notesController.text.isEmpty) return "SKIP";

    return "CONTINUE";
  }

  Future<bool> _validateCurrentPage() async {
    if (currentIndex == 1 && _weightController.text.isEmpty) {
      setState(() {
        _weightError = 'Please enter your current weight';
      });
      return false;
    }
    setState(() {
      _weightError = null;
    });
    return true;
  }

  Future<void> _navigateNext() async {
    if (_isAnimating) return;

    // Dismiss keyboard before navigation
    FocusScope.of(context).unfocus();

    setState(() => _isAnimating = true);
    _buttonAnimationController.forward();

    bool shouldResetAnimation = true;

    try {
      bool isValid = await _validateCurrentPage();
      if (!isValid) {
        // Validation failed, reset state immediately
        if (mounted) {
          _buttonAnimationController.reverse();
          setState(() => _isAnimating = false);
        }
        shouldResetAnimation = false;
        return;
      }

      if (currentIndex == 5) {
        // Submit check-in - closes wizard and returns to home
        await _submitCheckIn();
        // _submitCheckIn handles the animation state and navigation
        shouldResetAnimation = false;
      } else {
        // Move to next page (pages 0-4)
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

    // Dismiss keyboard before navigation
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
    final newWeight = int.tryParse(_weightController.text);
    if (newWeight == null || newWeight <= 0) {
      if (mounted) {
        _buttonAnimationController.reverse();
        setState(() {
          _weightError = 'Please enter a valid weight';
          _isAnimating = false;
        });
        // Go back to weight page
        _controller.jumpToPage(0);
      }
      return;
    }

    try {
      final success = await WeeklyCheckInService.processCheckInAndUpdateGoals(
        challenge: widget.challenge,
        newWeight: newWeight,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        progressFeeling: _selectedFeeling,
        activityLevelChange: _selectedActivityChange,
      );

      if (mounted) {
        if (success) {
          // Close the wizard and go back to home page
          _buttonAnimationController.reverse();
          setState(() => _isAnimating = false);
          Navigator.of(context).pop();
          widget.onCheckInComplete();
        } else {
          // If submission failed, show error and reset animation state
          _buttonAnimationController.reverse();
          setState(() {
            _isAnimating = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save check-in. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _buttonAnimationController.reverse();
        setState(() {
          _isAnimating = false;
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
        // Prevent back button from closing during processing
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

              // Horizontal Step Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _buildStepProgressIndicator(),
              ),

              // PageView with slides - wrapped in SingleChildScrollView per page
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
              if (currentIndex > 0)
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
                      ),
                    ),
                  ],
                )
              else
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
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  // Page 0: Welcome Page
  Widget _buildWelcomePage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting with Name - Biggest
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
                  style: TextStyle(
                    color: AppColors.secondary,
                  ),
                ),
                const TextSpan(text: "!"),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time for weekly check-in - Second level
          Text(
            "Time for your weekly check-in",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              height: 1.2,
            ),
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 16),

          // Description - Third level
          Text(
            "Your answers help us keep you on track.",
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 40),

          // What to expect section
          Text(
            "What to expect:",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              height: 1.2,
            ),
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 20),

          // Info items
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
        ],
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

  // Page 1: Weight Input
  Widget _buildWeightPage() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Title
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

            // Weight Input - Centered
            Center(
              child: Column(
                children: [
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    onTap: () {
                      // Only select all text, don't clear it
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
                          color: _weightError != null ? Colors.red : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _weightError != null ? Colors.red : AppColors.secondary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Title
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

          // Feeling Options - Centered
          Center(
            child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeelingOption('great', 'Great!', Icons.sentiment_very_satisfied),
                  _buildFeelingOption('good', 'Good', Icons.sentiment_satisfied),
                  _buildFeelingOption('okay', 'Okay', Icons.sentiment_neutral),
                  _buildFeelingOption('struggling', 'Struggling', Icons.sentiment_dissatisfied),
                ],
              ),
            ),
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Title
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

          // Activity Options - Centered
          Center(
            child: Column(
                children: [
                  _buildActivityOption('increased', 'Increased', Icons.trending_up),
                  const SizedBox(height: 12),
                  _buildActivityOption('no_change', 'No Change', Icons.trending_flat),
                  const SizedBox(height: 12),
                  _buildActivityOption('decreased', 'Decreased', Icons.trending_down),
                ],
              ),
            ),
          ],
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
            // Question Title
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

            // Notes Input - Centered
            TextField(
                controller: _notesController,
                maxLines: 5,
                maxLength: 150,
                style: const TextStyle(fontSize: 16),
                onTap: () {
                  // Select all text instead of clearing
                  if (_notesController.text.isNotEmpty) {
                    _notesController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _notesController.text.length,
                    );
                  }
                },
                onChanged: (value) {
                  setState(() {
                    // Trigger rebuild to update button text
                  });
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
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Title
          Text(
            "Ready to submit?",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Here's a summary of your weekly check-in.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Review Items
          Column(
                children: [
                  _buildReviewItem(
                    'Weight',
                    '${_weightController.text} kg',
                    Icons.monitor_weight_outlined,
                  ),
                  if (_selectedFeeling != null) ...[
                    const SizedBox(height: 12),
                    _buildReviewItem(
                      'How you feel',
                      _selectedFeeling!,
                      Icons.favorite_outline,
                    ),
                  ],
                  if (_selectedActivityChange != null) ...[
                    const SizedBox(height: 12),
                    _buildReviewItem(
                      'Activity level',
                      _selectedActivityChange!.replaceAll('_', ' '),
                      Icons.directions_run,
                    ),
                  ],
                  if (_notesController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReviewItem(
                      'Notes',
                      _notesController.text,
                      Icons.note_outlined,
                    ),
                  ],
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
