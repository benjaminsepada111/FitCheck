import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'profile_setup.dart';

class GoalSelectionPage extends StatefulWidget {
  const GoalSelectionPage({super.key});

  @override
  State<GoalSelectionPage> createState() => _GoalSelectionPageState();
}

class _GoalSelectionPageState extends State<GoalSelectionPage> with TickerProviderStateMixin {
  String? _selectedGoal;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> goals = [
    {
      "value": "fat loss",
      "label": "Lose Weight",
      "desc": "Create a calorie deficit for weight loss",
      "icon": Icons.trending_down_outlined,
      "detail": "Target: 0.5-1 kg per week",
      "color": Colors.red.shade400,
    },
    {
      "value": "maintain",
      "label": "Maintain Weight",
      "desc": "Keep your current weight stable",
      "icon": Icons.balance_outlined,
      "detail": "Focus on healthy habits",
      "color": Colors.blue.shade400,
    },
    {
      "value": "muscle gain",
      "label": "Gain Muscle",
      "desc": "Build muscle with a calorie surplus",
      "icon": Icons.trending_up_outlined,
      "detail": "Target: 0.25-0.5 kg per week",
      "color": Colors.green.shade400,
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

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _listController.forward();
    });

    _loadSavedGoal();
  }

  Future<void> _loadSavedGoal() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.goal != null && mounted) {
      setState(() {
        _selectedGoal = userData!.goal!;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _saveAndFinish() async {
    if (_selectedGoal == null) {
      _showErrorSnackBar('Please select a goal first.');
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final success = await UserDataService.updateUserData(goal: _selectedGoal);

      if (success && mounted) {
        // Navigate to profile setup
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      } else if (mounted) {
        _showErrorSnackBar('Failed to save goal. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ).createShader(bounds),
                      child: const Text(
                        "What's your goal?",
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
                      "This helps us calculate your daily calorie target",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      height: 3,
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Goal List
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ListView.builder(
                      itemCount: goals.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final isSelected = _selectedGoal == goal["value"];

                        return AnimatedContainer(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Material(
                            elevation: isSelected ? 6 : 2,
                            shadowColor: isSelected
                                ? goal["color"].withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() => _selectedGoal = goal["value"]);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            goal["color"].withOpacity(0.1),
                                            AppColors.secondary.withOpacity(0.05),
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? goal["color"]
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Goal Icon
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? goal["color"]
                                            : goal["color"].withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: goal["color"].withOpacity(0.4),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Icon(
                                        goal["icon"] as IconData,
                                        color: isSelected
                                            ? Colors.white
                                            : goal["color"],
                                        size: 32,
                                      ),
                                    ),

                                    const SizedBox(width: 20),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goal["label"]!,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? goal["color"]
                                                  : AppColors.primary,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            goal["desc"]!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
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

                                    // Selection indicator
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      height: 24,
                                      width: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? goal["color"]
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? goal["color"]
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
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

                const SizedBox(height: 32),

                // Finish Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'CONTINUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}