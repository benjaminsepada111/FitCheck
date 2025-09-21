// lib/LoginPages/verification_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import 'change_password.dart';
import '../color/colors.dart';
import '../services/forgot_password_service.dart.dart';

class VerificationPage extends StatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String code = "";
  int resendSeconds = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _isLoading = false;
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();

  // Error state for inline display
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _canResend = false;
    resendSeconds = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (resendSeconds > 0) {
          resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  // Clear errors
  void _clearErrors() {
    if (_codeError != null) {
      setState(() {
        _codeError = null;
      });
    }
  }

  // Set code error inline
  void _setCodeError(String message) {
    setState(() {
      _codeError = message;
    });
  }

  // Resend code - with inline error handling
  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _forgotPasswordService.sendPasswordResetCode(widget.email);

      if (success && mounted) {
        _startCountdown();

        // Show success using SnackBar instead of modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else if (mounted) {
        _setCodeError('Failed to resend code. Please try again');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to resend code';

        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please try again later';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        }

        _setCodeError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Verify code - REFACTORED
  Future<void> _verifyCode() async {
    _clearErrors();

    if (code.length != 5) {
      _setCodeError('Please enter the complete 5-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await _forgotPasswordService.verifyCode(widget.email, code);

      if (isValid && mounted) {
        // Navigate directly to change password - NO SUCCESS MODAL
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkingChangePasswordPage(
              email: widget.email,
              isVerified: true,
            ),
          ),
        );
      } else if (mounted) {
        _setCodeError('Invalid or expired verification code');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Verification failed';

        if (e.toString().contains('expired')) {
          errorMessage = 'Verification code has expired. Please request a new one';
        } else if (e.toString().contains('invalid')) {
          errorMessage = 'Invalid verification code. Please try again';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        }

        _setCodeError(errorMessage);
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
            // Title
            const Text(
              "Verify Your Email",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Inline message instead of modal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.email, color: AppColors.secondary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Verification code sent!',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 5-digit verification code to ${widget.email}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              "Enter Verification Code",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // PIN Code Field
            PinCodeTextField(
              appContext: context,
              length: 5,
              keyboardType: TextInputType.number,
              textStyle: const TextStyle(color: Colors.white, fontSize: 20),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 55,
                fieldWidth: 50,
                activeFillColor: const Color(0xFF1A2332),
                inactiveFillColor: const Color(0xFF1A2332),
                selectedFillColor: const Color(0xFF1A2332),
                activeColor: _codeError != null ? Colors.red : AppColors.secondary,
                inactiveColor: _codeError != null ? Colors.red : Colors.grey,
                selectedColor: AppColors.secondary,
              ),
              enableActiveFill: true,
              onChanged: (value) {
                code = value;
                _clearErrors();
              },
              onCompleted: (value) {
                code = value;
              },
            ),

            // Inline error message for code
            if (_codeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  _codeError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Verify Button
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
                onPressed: code.length == 5 && !_isLoading ? _verifyCode : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "VERIFY CODE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Resend section
            Center(
              child: Column(
                children: [
                  if (!_canResend)
                    Text(
                      "Didn't receive the code? Resend in ${resendSeconds}s",
                      style: const TextStyle(color: Colors.grey),
                    )
                  else
                    GestureDetector(
                      onTap: _resendCode,
                      child: const Text(
                        "Didn't receive the code? Resend now",
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Help section
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
                        'Trouble receiving the code?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Check your spam or junk folder\n• Ensure you entered the correct email\n• Try requesting a new code if this one expired',
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