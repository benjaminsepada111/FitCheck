import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'onboarding_navigation.dart';

class HeightPage extends StatefulWidget {
  const HeightPage({super.key});

  @override
  State<HeightPage> createState() => _HeightPageState();
}

class _HeightPageState extends State<HeightPage>
    with TickerProviderStateMixin {
  final TextEditingController _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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

    _loadSavedHeight();
  }

  Future<void> _loadSavedHeight() async {
    // Load from temporary onboarding data if available
    final nav = OnboardingNavigation.of(context);
    if (nav?.data.height != null && mounted) {
      setState(() {
        _heightController.text = nav!.data.height!.toString();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoading) return;

    // Dismiss keyboard before navigation
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      // Store data temporarily in OnboardingData instead of saving to Firebase
      final nav = OnboardingNavigation.of(context);
      if (nav != null) {
        final height = int.tryParse(_heightController.text.trim());
        if (height != null) {
          nav.data.height = height;

          // Move to next page (summary page)
          if (nav.onNext != null) {
            nav.onNext!();
          }
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header Section
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  // Title
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [AppColors.primary, AppColors.primary],
                                    ).createShader(bounds),
                                    child: const Text(
                                      "Height",
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
                                    "Enter your height",
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

                            const SizedBox(height: 50),

                            // Height Input Field
                            Center(
                              child: SizedBox(
                                width: 280,
                                child: TextFormField(
                                  controller: _heightController,
                                  autofocus: false,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your height',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 18,
                                    ),
                                    suffixText: 'cm',
                                    suffixStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
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
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 2),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 2.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your height';
                                }
                                final height = int.tryParse(value.trim());
                                if (height == null) {
                                  return 'Please enter a valid number';
                                }
                                    if (height < 100 || height > 320) {
                                      return 'Height must be between 100-320 cm';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
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
                          // Dismiss keyboard before navigation
                          FocusScope.of(context).unfocus();
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
}
