import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'onboarding_navigation.dart';

class HobbiesPage extends StatefulWidget {
  const HobbiesPage({super.key});

  @override
  State<HobbiesPage> createState() => _HobbiesPageState();
}

class _HobbiesPageState extends State<HobbiesPage> with TickerProviderStateMixin {
  final TextEditingController _bioController = TextEditingController();
  final Set<String> _selectedHobbies = {};
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Predefined hobbies
  final List<Map<String, dynamic>> _hobbies = [
    {'name': 'Running', 'icon': Icons.directions_run},
    {'name': 'Cycling', 'icon': Icons.directions_bike},
    {'name': 'Swimming', 'icon': Icons.pool},
    {'name': 'Yoga', 'icon': Icons.self_improvement},
    {'name': 'Gym', 'icon': Icons.fitness_center},
    {'name': 'Dancing', 'icon': Icons.music_note},
    {'name': 'Hiking', 'icon': Icons.terrain},
    {'name': 'Sports', 'icon': Icons.sports_basketball},
    {'name': 'Cooking', 'icon': Icons.restaurant},
    {'name': 'Reading', 'icon': Icons.menu_book},
    {'name': 'Photography', 'icon': Icons.camera_alt},
    {'name': 'Gaming', 'icon': Icons.sports_esports},
  ];

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

    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    // Load from temporary onboarding data if available
    final nav = OnboardingNavigation.of(context);
    if (nav != null && mounted) {
      setState(() {
        _bioController.text = nav.data.bio ?? '';
        _selectedHobbies.addAll(nav.data.hobbies);
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Store data temporarily in OnboardingData instead of saving to Firebase
      final nav = OnboardingNavigation.of(context);
      if (nav != null) {
        nav.data.bio = _bioController.text.trim().isEmpty ? null : _bioController.text.trim();
        nav.data.hobbies = _selectedHobbies.toList();

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

  void _toggleHobby(String hobby) {
    setState(() {
      if (_selectedHobbies.contains(hobby)) {
        _selectedHobbies.remove(hobby);
      } else {
        _selectedHobbies.add(hobby);
      }
    });
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
                      const SizedBox(height: 40),

                        // Header Section
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [AppColors.primary, AppColors.primary],
                                ).createShader(bounds),
                                child: const Text(
                                  "Tell us about yourself",
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
                                "Select your interests and hobbies",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Hobbies Selection
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _hobbies.map((hobby) {
                            final isSelected = _selectedHobbies.contains(hobby['name']);
                            return _buildHobbyChip(
                              hobby['name'] as String,
                              hobby['icon'] as IconData,
                              isSelected,
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 30),

                        // Bio Section (Optional)
                        TextFormField(
                          controller: _bioController,
                          maxLines: 3,
                          maxLength: 200,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tell us more about yourself (optional)...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.secondary, width: 2.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

              // Navigation Buttons (Fixed at bottom)
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

  Widget _buildHobbyChip(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleHobby(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.secondary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
