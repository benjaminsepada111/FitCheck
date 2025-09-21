  import 'package:flutter/material.dart';
  import '../color/colors.dart';
  import 'package:capstone_project/services/user_data_service.dart';

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

  class GoalPage extends StatefulWidget {
    const GoalPage({super.key});

    @override
    State<GoalPage> createState() => _GoalPageState();
  }

  class _GoalPageState extends State<GoalPage> with TickerProviderStateMixin {
    String? _selectedGoal;
    double _adjustment = 500; // default kcal
    bool _showAdjustment = false; // Make adjustment optional

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
                                    // Reset adjustment visibility when goal changes
                                    _showAdjustment = false;
                                  });
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
                                              style: TextStyle(
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
                                              _saveGoal(value!, _showAdjustment ? _adjustment : null);
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