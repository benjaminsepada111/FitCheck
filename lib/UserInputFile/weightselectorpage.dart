import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/color/colors.dart';
import 'onboarding_navigation.dart';

// Custom input formatter to allow numbers with max 1 decimal place
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }
    
    // Check if it's a valid decimal number with max 1 decimal place
    final regex = RegExp(r'^\d+\.?\d{0,1}$');
    if (regex.hasMatch(text)) {
      return newValue;
    }
    
    // If not valid, return old value
    return oldValue;
  }
}

class WeightSelectorPage extends StatefulWidget {
  const WeightSelectorPage({Key? key}) : super(key: key);

  @override
  State<WeightSelectorPage> createState() => _WeightSelectorPageState();
}

class _WeightSelectorPageState extends State<WeightSelectorPage>
    with TickerProviderStateMixin {
  final TextEditingController _weightController = TextEditingController();
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

    _loadSavedWeight();
  }

  Future<void> _loadSavedWeight() async {
    // Load from temporary onboarding data if available
    final nav = OnboardingNavigation.of(context);
    if (nav?.data.weight != null && mounted) {
      setState(() {
        _weightController.text = nav!.data.weight!.toString();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _weightController.dispose();
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
        final weight = double.tryParse(_weightController.text.trim());
        if (weight != null) {
          nav.data.weight = weight;

          // Move to next page
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
                                      "Weight",
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
                                    "Enter your current weight",
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

                            // Weight Input Field
                            Center(
                              child: SizedBox(
                                width: 280,
                                child: TextFormField(
                                  controller: _weightController,
                                  autofocus: false,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    DecimalTextInputFormatter(),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your weight',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 18,
                                    ),
                                    suffixText: 'kg',
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
                                  return 'Please enter your weight';
                                }
                                final weight = double.tryParse(value.trim());
                                if (weight == null) {
                                  return 'Please enter a valid number';
                                }
                                // Check decimal places
                                final parts = value.trim().split('.');
                                if (parts.length > 1 && parts[1].length > 1) {
                                  return 'Only 1 decimal place allowed';
                                }
                                    if (weight < 20 || weight > 300) {
                                      return 'Weight must be between 20-300 kg';
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
