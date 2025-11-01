import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/calorie_calculator.dart';
import 'package:capstone_project/services/challenge_service.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateChallengeSheet extends StatefulWidget {
  final dynamic Function(Challenge) onChallengeCreated;

  const CreateChallengeSheet({super.key, required this.onChallengeCreated});

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Basic challenge info
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  // Activity Level & Goal
  String? _selectedLifestyleLevel;
  String? _selectedGoal;
  double _goalAdjustment = 500;
  bool _showAdjustment = false;

  // Calculated values
  int _calculatedCalorieGoal = 0;

  bool _isCreating = false;
  bool _isCalculating = false;
  UserData? _userData;

  final List<Map<String, dynamic>> lifestyleLevels = [
    {
      "value": "lightly_active",
      "label": "Lightly Active",
      "desc":
          "Desk job, student, or light daily activity. Example: Office worker who walks occasionally",
      "icon": Icons.chair_outlined,
      "multiplier": 1.375,
    },
    {
      "value": "active",
      "label": "Active",
      "desc":
          "On your feet regularly. Example: Teacher, retail worker, or parent with young kids",
      "icon": Icons.directions_walk_outlined,
      "multiplier": 1.55,
    },
    {
      "value": "very_active",
      "label": "Very Active",
      "desc":
          "Physically demanding work or very active lifestyle. Example: Nurse, construction worker",
      "icon": Icons.fitness_center_outlined,
      "multiplier": 1.725,
    },
    {
      "value": "extra_active",
      "label": "Extra Active",
      "desc":
          "Highly physical job or training multiple times daily. Example: Athlete, fitness trainer",
      "icon": Icons.sports_outlined,
      "multiplier": 1.9,
    },
  ];

  final List<Map<String, dynamic>> goals = [
    {
      "value": "lose_fat",
      "label": "Lose Fat",
      "desc":
          "Eat fewer calories than you burn to reduce fat while maintaining muscle",
      "icon": Icons.trending_down,
      "adjustment": -500,
    },
    {
      "value": "maintain_weight",
      "label": "Maintain Weight",
      "desc": "Keep your current weight steady with balanced eating",
      "icon": Icons.balance,
      "adjustment": 0,
    },
    {
      "value": "gain_muscle",
      "label": "Gain Muscle",
      "desc": "Eat slightly more than you burn to support muscle growth",
      "icon": Icons.trending_up,
      "adjustment": 500,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLifestyleLevel = "lightly_active"; // Set default
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _userData = await UserDataService.loadUserData();
    setState(() {});
  }

  Future<bool> _requestCalendarPermission() async {
    var status = await Permission.calendar.status;

    if (status.isDenied || status.isRestricted) {
      status = await Permission.calendar.request();
    }

    return status.isGranted;
  }


  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      TextEditingController controller,
      bool isStartDate,
      ) async {

    bool granted = await _requestCalendarPermission();
    if (!granted) {
      _showError("Calendar permission is required.");
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026, 12),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.secondary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
            _endDateController.clear();
          }
        } else {
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _showError('End date cannot be before start date');
            return;
          }
          _endDate = picked;
        }
      });
      controller.text =
      '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
    }
  }


  void _calculateGoals() async {
    if (_userData == null ||
        _selectedLifestyleLevel == null ||
        _selectedGoal == null) {
      return;
    }

    setState(() => _isCalculating = true);

    try {
      // Create temporary user data with challenge-specific activity and goal
      final tempUserData = _userData!.copyWith(
        activityLevel: _selectedLifestyleLevel,
        goal: _selectedGoal,
        goalAdjustment: _showAdjustment ? _goalAdjustment : null,
      );

      if (CalorieCalculator.isValidUserData(tempUserData)) {
        _calculatedCalorieGoal = CalorieCalculator.calculateDailyCalorieGoal(
          tempUserData,
        );
      } else {
        _calculatedCalorieGoal = 2000;
      }
    } catch (e) {
      _calculatedCalorieGoal = 2000;
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  bool _validatePage1() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a challenge title');
      return false;
    }
    if (_startDate == null) {
      _showError('Please select a start date');
      return false;
    }
    if (_endDate == null) {
      _showError('Please select an end date');
      return false;
    }
    return true;
  }

  bool _validatePage2() {
    if (_selectedLifestyleLevel == null) {
      _showError('Please select how active you are outside of workouts');
      return false;
    }
    if (_selectedGoal == null) {
      _showError('Please select a goal');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _createChallenge() async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final challenge = Challenge(
        id: ChallengeService.generateChallengeId(),
        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        dailyCalorieGoal: _calculatedCalorieGoal,
        createdAt: DateTime.now(),
        notes: _notesController.text.trim(),
      );

      final success = await ChallengeService.createChallenge(challenge);

      if (success) {
        widget.onChallengeCreated(challenge);
        _showSuccess('Challenge created successfully!');
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save challenge');
      }
    } catch (e) {
      _showError('Failed to create challenge. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_validatePage1()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_currentPage == 1) {
      if (_validatePage2()) {
        _calculateGoals();
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _createChallenge();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: _previousPage,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      "Create Challenge",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress indicator
            Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? AppColors.secondary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // PageView
            Flexible(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage1BasicInfo(),
                  _buildPage2ActivityAndGoal(),
                  _buildPage3Review(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Navigation button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isCreating || _isCalculating) ? null : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: (_isCreating || _isCalculating)
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _currentPage == 2 ? 'CREATE CHALLENGE' : 'CONTINUE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1BasicInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Basic Information",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Challenge Title
          _buildTextField(
            label: 'Challenge Title *',
            controller: _titleController,
            hint: 'e.g., Summer Fitness Challenge',
          ),
          const SizedBox(height: 20),

          // Dates
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Start Date *',
                  controller: _startDateController,
                  onTap: () => _selectDate(_startDateController, true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDateField(
                  label: 'End Date *',
                  controller: _endDateController,
                  onTap: () => _selectDate(_endDateController, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Notes
          _buildTextField(
            label: 'Notes (Optional)',
            controller: _notesController,
            hint: 'Add your personal motivation...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPage2ActivityAndGoal() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Activity & Goal",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Lifestyle Level
          Text(
            "How active are you outside of workouts? *",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This is your baseline daily activity before workouts. Exercise calories will be added separately.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...lifestyleLevels.map((level) => _buildLifestyleLevelOption(level)),

          const SizedBox(height: 24),

          // Goal
          Text(
            "Your Goal *",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...goals.map((goal) => _buildGoalOption(goal)),

          // Adjustment slider (if not maintain)
          if (_selectedGoal != null && _selectedGoal != "maintain_weight") ...[
            const SizedBox(height: 20),
            _buildAdjustmentSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildPage3Review() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Review & Confirm",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Summary
          _buildSummaryItem("Title", _titleController.text),
          _buildSummaryItem(
            "Duration",
            _startDate != null && _endDate != null
                ? "${_startDate!.month}/${_startDate!.day} - ${_endDate!.month}/${_endDate!.day}"
                : "",
          ),
          _buildSummaryItem(
            "Lifestyle",
            lifestyleLevels.firstWhere(
                  (l) => l["value"] == _selectedLifestyleLevel,
                  orElse: () => {"label": ""},
                )["label"] ??
                "",
          ),
          _buildSummaryItem(
            "Goal",
            goals.firstWhere(
                  (g) => g["value"] == _selectedGoal,
                  orElse: () => {"label": ""},
                )["label"] ??
                "",
          ),

          const SizedBox(height: 24),

          // Calculated goals
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  "Your Daily Calorie Goal",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Baseline before exercise calories",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _buildGoalCard(
                    "$_calculatedCalorieGoal",
                    "Calories per day",
                    Icons.local_fire_department,
                    AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Exercise calories will be added when you log workouts",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: "mm/dd/yyyy",
            suffixIcon: Icon(Icons.calendar_today, color: AppColors.secondary),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleLevelOption(Map<String, dynamic> level) {
    final isSelected = _selectedLifestyleLevel == level["value"];
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLifestyleLevel = level["value"]);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              level["icon"],
              color: isSelected ? AppColors.secondary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level["label"],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.secondary : Colors.black,
                    ),
                  ),
                  Text(
                    level["desc"],
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOption(Map<String, dynamic> goal) {
    final isSelected = _selectedGoal == goal["value"];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goal["value"];
          _showAdjustment = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              goal["icon"],
              color: isSelected ? AppColors.secondary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal["label"],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.secondary : Colors.black,
                    ),
                  ),
                  Text(
                    goal["desc"],
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Customize ${_selectedGoal == 'lose_fat' ? 'deficit' : 'surplus'}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _showAdjustment,
                onChanged: (value) {
                  setState(() => _showAdjustment = value);
                },
                activeColor: AppColors.secondary,
              ),
            ],
          ),
          if (_showAdjustment) ...[
            const SizedBox(height: 12),
            Slider(
              value: _goalAdjustment,
              min: 200,
              max: 1000,
              divisions: 8,
              label: "${_goalAdjustment.round()} kcal",
              onChanged: (val) {
                setState(() => _goalAdjustment = val);
              },
              activeColor: AppColors.secondary,
            ),
            Text(
              "${_selectedGoal == 'lose_fat' ? '-' : '+'}${_goalAdjustment.round()} kcal/day",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
