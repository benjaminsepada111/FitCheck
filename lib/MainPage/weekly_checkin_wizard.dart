import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/weekly_checkin_service.dart';

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
  }

  List<Widget> _getSlides() {
    return [
      _buildWeightPage(),
      _buildFeelingPage(),
      _buildActivityPage(),
      _buildNotesPage(),
      _buildReviewPage(),
      _buildSuccessPage(),
    ];
  }

  Widget _buildStepProgressIndicator() {
    const int totalSteps = 5; // 5 steps (pages 0-4, excluding success page)

    return Row(
      children: List.generate(totalSteps, (index) {
        final bool isCompleted = index < currentIndex;
        final bool isCurrent = index == currentIndex;

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
    if (currentIndex == 0) return "NEXT";
    if (currentIndex == 4) return "SUBMIT";
    if (currentIndex == 5) return "DONE";

    // Pages 1, 2, 3 (Feeling, Activity, Notes) - show SKIP if nothing selected
    if (currentIndex == 1 && _selectedFeeling == null) return "SKIP";
    if (currentIndex == 2 && _selectedActivityChange == null) return "SKIP";
    if (currentIndex == 3 && _notesController.text.isEmpty) return "SKIP";

    return "CONTINUE";
  }

  Future<bool> _validateCurrentPage() async {
    if (currentIndex == 0 && _weightController.text.isEmpty) {
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

    setState(() => _isAnimating = true);
    _buttonAnimationController.forward();

    try {
      bool isValid = await _validateCurrentPage();
      if (!isValid) return;

      if (currentIndex == 4) {
        // Submit check-in
        await _submitCheckIn();
      } else if (currentIndex == 5) {
        // Done button on success page
        Navigator.pop(context);
        widget.onCheckInComplete();
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
          if (mounted) setState(() => _isAnimating = false);
        });
      }
    }
  }

  Future<void> _navigateBack() async {
    if (_isAnimating || currentIndex <= 0) return;

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
      setState(() {
        _weightError = 'Please enter a valid weight';
      });
      // Go back to weight page
      _controller.jumpToPage(0);
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

      if (success && mounted) {
        // Navigate to success page
        await _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (e) {
      // Silent fail - could add error handling if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isProcessing = _isAnimating;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Back Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (currentIndex > 0 && currentIndex < 5)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28),
                      color: AppColors.secondary,
                      onPressed: isProcessing ? null : _navigateBack,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Horizontal Step Progress Indicator
              if (currentIndex < 5)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildStepProgressIndicator(),
                ),

              // PageView with slides
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

              // Button (hide on success page)
              if (currentIndex < 5)
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
    );
  }

  // Page 1: Weight Input
  Widget _buildWeightPage() {
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ).createShader(bounds),
                child: const Text(
                  "Current Weight",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We use this to recalculate your daily calorie goal.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Weight Input
              Column(
                children: [
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    onTap: () {
                      _weightController.clear();
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
            ],
          ),
        ),
      ),
    );
  }

  // Page 2: Feeling Selection
  Widget _buildFeelingPage() {
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ).createShader(bounds),
                child: const Text(
                  "How You Feel",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "How do you feel this week?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Feeling Options
              Wrap(
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
            ],
          ),
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
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ).createShader(bounds),
                child: const Text(
                  "Activity Level",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Has your activity level changed?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Activity Options
              Column(
                children: [
                  _buildActivityOption('increased', 'Increased', Icons.trending_up),
                  const SizedBox(height: 12),
                  _buildActivityOption('no_change', 'No Change', Icons.trending_flat),
                  const SizedBox(height: 12),
                  _buildActivityOption('decreased', 'Decreased', Icons.trending_down),
                ],
              ),
            ],
          ),
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
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ).createShader(bounds),
                child: const Text(
                  "Notes",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Anything else you want to note about your week?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Notes Input
              TextField(
                controller: _notesController,
                maxLines: 5,
                maxLength: 150,
                style: const TextStyle(fontSize: 16),
                onTap: () {
                  _notesController.clear();
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
      ),
    );
  }

  // Page 5: Review
  Widget _buildReviewPage() {
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ).createShader(bounds),
                child: const Text(
                  "Review",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Let's update your stats to keep your plan on track.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

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
        ),
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

  // Page 6: Success
  Widget _buildSuccessPage() {
    return Container(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'You\'re making great progress!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Keep it up.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Done Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCheckInComplete();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
