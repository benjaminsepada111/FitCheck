  import 'package:flutter/material.dart';
  import 'package:capstone_project/color/colors.dart';
  import 'package:capstone_project/services/user_data_service.dart';
  import 'onboarding_navigation.dart';

  class GenderSelection extends StatefulWidget {
    const GenderSelection({super.key});

    @override
    State<GenderSelection> createState() => _GenderSelectionState();
  }

  class _GenderSelectionState extends State<GenderSelection> with TickerProviderStateMixin {
    String selectedGender = "Female"; // Default selected
    bool _isLoading = false;
    late AnimationController _fadeController;
    late AnimationController _scaleController;
    late Animation<double> _fadeAnimation;
    late Animation<double> _scaleAnimation;

    @override
    void initState() {
      super.initState();

      // Fade animation for the entire content
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _fadeAnimation = CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      );

      // Scale animation for selection feedback
      _scaleController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ));

      // Start fade animation
      _fadeController.forward();
    }

    @override
    void dispose() {
      _fadeController.dispose();
      _scaleController.dispose();
      super.dispose();
    }

    void _onGenderTap(String gender) {
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });

      setState(() {
        selectedGender = gender;
      });
    }

    Future<void> _saveAndContinue() async {
      if (_isLoading) return;

      setState(() => _isLoading = true);

      try {
        // Store data temporarily in OnboardingData instead of saving to Firebase
        final nav = OnboardingNavigation.of(context);
        if (nav != null) {
          nav.data.gender = selectedGender;

          // Move to next page
          if (nav.onNext != null) {
            nav.onNext!();
          }
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // Header Section with enhanced styling
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          // Title with gradient text effect
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [AppColors.primary, AppColors.primary],
                            ).createShader(bounds),
                            child: const Text(
                              "Gender",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle with better styling
                          Text(
                            "Select your gender for personalized calculations",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Decorative line

                        ],
                      ),
                    ),

                    const SizedBox(height: 50),

                    // Gender Options with enhanced design
                    Row(
                      children: [
                        // Male Option
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: selectedGender == "Male" ? _scaleAnimation.value : 1.0,
                                child: genderOption(
                                  title: "Male",
                                  icon: Icons.male,
                                  color: Colors.blue.shade600,
                                  isSelected: selectedGender == "Male",
                                  onTap: () => _onGenderTap("Male"),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 20),

                        // Female Option
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: selectedGender == "Female" ? _scaleAnimation.value : 1.0,
                                child: genderOption(
                                  title: "Female",
                                  icon: Icons.female,
                                  color: Colors.pink.shade400,
                                  isSelected: selectedGender == "Female",
                                  onTap: () => _onGenderTap("Female"),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
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
                        onPressed: _isLoading ? null : () {
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

                    // Next Button
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'NEXT',
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

    Widget genderOption({
      required String title,
      required IconData icon,
      required Color color,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                AppColors.secondary.withOpacity(0.05),
              ],
            )
                : null,
            color: isSelected ? null : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.secondary : Colors.grey.shade200,
              width: isSelected ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.secondary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced CircleAvatar with glow effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                      : [],
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: color,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      icon,
                      size: isSelected ? 65 : 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Enhanced title text
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: isSelected ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
                child: Text(title),
              ),

              // Selection indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: isSelected ? 30 : 0,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }