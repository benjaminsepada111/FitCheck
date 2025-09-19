import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/LoginPages/login_page.dart';
import 'signupverification_page.dart';
import '../color/colors.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Error states for inline display
  String? _emailError;
  String? _termsError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Clear errors when user starts typing
  void _clearErrors() {
    if (_emailError != null || _termsError != null) {
      setState(() {
        _emailError = null;
        _termsError = null;
      });
    }
  }

  // Set email error inline
  void _setEmailError(String message) {
    setState(() {
      _emailError = message;
    });
  }

  // Set terms error inline
  void _setTermsError(String message) {
    setState(() {
      _termsError = message;
    });
  }

  // FIXED: Now properly uses EmailJS integration from AuthService
  Future<String> _sendOTPToEmail(String email) async {
    try {
      // Use the existing EmailJS integration from AuthService
      String otp = await _authService.sendOTPViaEmailJS(
        email,
        userName: email.split('@')[0], // Extract username from email
      );

      print('OTP successfully sent via EmailJS to $email');
      return otp;
    } catch (e) {
      // AuthService already handles cleanup and detailed error messages
      print('Failed to send OTP via EmailJS: $e');
      rethrow;
    }
  }

  // Send OTP and navigate to verification - REFACTORED
  Future<void> _sendOTPAndNavigate() async {
    _clearErrors();

    // Validate email field
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setEmailError('Please enter your email address');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _setEmailError('Please enter a valid email address');
      return;
    }

    // Validate terms agreement
    if (!_agreeToTerms) {
      _setTermsError('Please agree to the Terms of Service and Privacy Policy');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if email is already registered
      bool isEmailRegistered = await _authService.isEmailRegistered(email).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      if (isEmailRegistered) {
        _setEmailError('This email is already registered. Please use a different email or try logging in.');
        return;
      }

      // Send OTP via EmailJS (this now actually sends the email!)
      await _sendOTPToEmail(email);

      // Navigate directly to verification page - NO SUCCESS MODAL
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationPage(
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send verification code';

        // Handle specific EmailJS errors
        if (e.toString().contains('Email sending timed out')) {
          errorMessage = 'Email sending timed out. Please check your internet connection and try again';
        } else if (e.toString().contains('timeout') || e.toString().contains('network')) {
          errorMessage = 'Connection timeout. Please check your internet connection and try again';
        } else if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Please try again';
        } else if (e.toString().contains('unavailable')) {
          errorMessage = 'Service temporarily unavailable. Please try again later';
        } else if (e.toString().contains('Failed to send email')) {
          errorMessage = 'Failed to send verification email. Please check your email address and try again';
        }

        _setEmailError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF06111D),
      body: Stack(
        children: [
          // Background SVG
          Positioned(
            top: 0,
            left: -10,
            right: 175,
            child: SizedBox(
              height: 359,
              child: SvgPicture.asset(
                "assets/login_svg/bg.svg",
                color: AppColors.secondary,
              ),
            ),
          ),

          // Title and subtitle
          const Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Create your account",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Main form
          Positioned(
            top: 280,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email TextField with inline error
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _clearErrors(),
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(
                          color: _emailError != null ? Colors.red : Colors.grey,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A2332),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _emailError != null ? Colors.red : Colors.transparent,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _emailError != null ? Colors.red : Colors.transparent,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _emailError != null ? Colors.red : AppColors.secondary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Inline error message for email
                    if (_emailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _emailError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Terms and conditions checkbox with inline error
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                            _clearErrors();
                          },
                          activeColor: AppColors.secondary,
                          checkColor: Colors.white,
                          side: BorderSide(
                            color: _termsError != null ? Colors.red : Colors.grey,
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: _termsError != null ? Colors.red : Colors.white,
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(text: "I agree to the "),
                                TextSpan(
                                  text: "Terms of Service",
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(text: " and "),
                                TextSpan(
                                  text: "Privacy Policy",
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Inline error message for terms
                    if (_termsError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _termsError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _sendOTPAndNavigate,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "SEND VERIFICATION CODE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign In Link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Sign In",
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
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