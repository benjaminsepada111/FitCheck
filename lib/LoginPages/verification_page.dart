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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  Future<void> _verifyCode() async {
    if (code.length != 5) {
      _showErrorDialog('Please enter the complete 5-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = _forgotPasswordService.verifyCode(widget.email, code);

      if (isValid) {
        _showSuccessMessage('Code verified successfully!');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkingChangePasswordPage(
                email: widget.email,
                isVerified: true,
              ),
            ),
          );
        }
      } else {
        _showErrorDialog('Invalid or expired verification code');
      }
    } catch (e) {
      _showErrorDialog('Verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _forgotPasswordService.resendCode(widget.email);

      if (success) {
        _showSuccessMessage('New verification code sent!');
        _startCountdown();
        setState(() {
          code = "";
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to resend code. Please try again.');
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Verification",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "We have sent a code to your email\n${widget.email}",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Positioned(
            top: 0,
            left: 100,
            right: -10,
            child: SizedBox(
              height: 230,
              child: SvgPicture.asset(
                "assets/login_svg/bg2.svg",
                color: AppColors.secondary,
              ),
            ),
          ),

          // Verification Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Code input label
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "CODE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pin code fields
                  PinCodeTextField(
                    length: 5,
                    appContext: context,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    enabled: !_isLoading,
                    onChanged: (value) {
                      setState(() => code = value);
                    },
                    onCompleted: (value) {
                      // Auto-verify when code is complete
                      if (value.length == 5) {
                        _verifyCode();
                      }
                    },
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 55,
                      fieldWidth: 50,
                      activeFillColor: Colors.grey[200],
                      selectedFillColor: Colors.grey[200],
                      inactiveFillColor: Colors.grey[200],
                      activeColor: Colors.transparent,
                      selectedColor: AppColors.secondary,
                      inactiveColor: Colors.transparent,
                    ),
                    enableActiveFill: true,
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
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "VERIFY",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend timer/button
                  GestureDetector(
                    onTap: _canResend && !_isLoading ? _resendCode : null,
                    child: Text(
                      _canResend
                          ? "Didn't get the code? Resend now"
                          : "Didn't get the code? Resend in ${resendSeconds}s",
                      style: TextStyle(
                        color: _canResend ? AppColors.secondary : Colors.grey,
                        fontWeight: _canResend ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),

                  const SizedBox(height: 250),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}