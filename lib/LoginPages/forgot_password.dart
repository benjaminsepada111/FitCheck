// lib/LoginPages/forgot_password.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'verification_page.dart';
import '../color/colors.dart';
import '../services/forgot_password_service.dart.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();
  bool _isLoading = false;

  // Error state for inline display
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Clear errors when user starts typing
  void _clearErrors() {
    if (_emailError != null) {
      setState(() {
        _emailError = null;
      });
    }
  }

  // Set email error inline
  void _setEmailError(String message) {
    setState(() {
      _emailError = message;
    });
  }

  // Send reset code - REFACTORED
  Future<void> _sendResetCode() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _forgotPasswordService.sendPasswordResetCode(email);

      if (success && mounted) {
        // Navigate directly to verification page - NO SUCCESS MODAL
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationPage(email: email),
          ),
        );
      } else if (mounted) {
        _setEmailError('Failed to send reset code. Please try again');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send reset code';

        if (e.toString().contains('user-not-found')) {
          errorMessage = 'No account found with this email address';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email address format';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please try again later';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
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
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            const Text(
              "Forgot Password",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Enter your email address and we'll send you a verification code to reset your password.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 48),

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
                    labelText: "Email Address",
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
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
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

            // Send Reset Code Button
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
                onPressed: _isLoading ? null : _sendResetCode,
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

            // Back to login link
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Back to Sign In",
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Help text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Make sure to check your spam folder if you don\'t receive the verification code within a few minutes.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}