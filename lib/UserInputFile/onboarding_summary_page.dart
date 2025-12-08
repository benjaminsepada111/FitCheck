import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'onboarding_navigation.dart';

class OnboardingSummaryPage extends StatefulWidget {
  final String name;
  final String? bio;
  final List<String> hobbies;
  final String gender;
  final DateTime birthDate;
  final double weight; // Changed to double to support decimal display
  final int height;

  const OnboardingSummaryPage({
    super.key,
    required this.name,
    this.bio,
    required this.hobbies,
    required this.gender,
    required this.birthDate,
    required this.weight,
    required this.height,
  });

  @override
  State<OnboardingSummaryPage> createState() => _OnboardingSummaryPageState();
}

class _OnboardingSummaryPageState extends State<OnboardingSummaryPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  int get calculatedAge {
    final now = DateTime.now();
    int age = now.year - widget.birthDate.year;
    if (now.month < widget.birthDate.month ||
        (now.month == widget.birthDate.month && now.day < widget.birthDate.day)) {
      age--;
    }
    return age;
  }

  String get formattedBirthDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[widget.birthDate.month - 1]} ${widget.birthDate.day}, ${widget.birthDate.year}';
  }

  Future<void> _confirmAndSave() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Save all data to Firebase at once
      final success = await UserDataService.updateUserData(
        name: widget.name,
        bio: widget.bio,
        hobbies: widget.hobbies,
        gender: widget.gender,
        birthDate: widget.birthDate,
        weight: widget.weight, // Store with decimal precision
        height: widget.height,
      );

      if (success && mounted) {
        // Navigate to main app
        final nav = OnboardingNavigation.of(context);
        if (nav?.onNext != null) {
          nav!.onNext!();
        }
      } else if (mounted) {
        _showErrorSnackBar('Failed to save your profile. Please try again.');
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Greeting Header
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                        ).createShader(bounds),
                        child: Text(
                          "Hello, ${widget.name}!",
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        "Welcome to FitCheck",
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // Summary Cards
                      _buildSummaryCard(
                        icon: Icons.person_outline,
                        title: "About You",
                        children: [
                          if (widget.bio != null && widget.bio!.isNotEmpty)
                            _buildInfoRow("Bio", widget.bio!),
                          if (widget.hobbies.isNotEmpty)
                            _buildHobbiesRow("Hobbies", widget.hobbies),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _buildSummaryCard(
                        icon: Icons.info_outline,
                        title: "Personal Details",
                        children: [
                          _buildInfoRow("Gender", widget.gender),
                          _buildInfoRow("Born on", "$formattedBirthDate ($calculatedAge years old)"),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _buildSummaryCard(
                        icon: Icons.monitor_weight_outlined,
                        title: "Physical Stats",
                        children: [
                          _buildInfoRow("Weight", "${widget.weight.toStringAsFixed(1)} kg"),
                          _buildInfoRow("Height", "${widget.height} cm"),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Back Button
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                final nav = OnboardingNavigation.of(context);
                                if (nav?.onBack != null) {
                                  nav!.onBack!();
                                }
                              },
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

                    // Confirm Button
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _confirmAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'CONFIRM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.secondary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHobbiesRow(String label, List<String> hobbies) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hobbies.map((hobby) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  hobby,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
