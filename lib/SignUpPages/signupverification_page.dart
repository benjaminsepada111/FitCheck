import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:capstone_project/color/colors.dart';
import '../services/auth_service.dart';
import '../UserInputFile/onboarding_screen.dart';
import 'dart:async';

class VerificationPage extends StatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String code = "";
  int resendSeconds = 60;
  Timer? _timer;
  bool _isLoading = false;
  bool _isCodeVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Error states for inline display
  String? _otpError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && resendSeconds > 0) {
        setState(() {
          resendSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Clear errors
  void _clearErrors() {
    setState(() {
      _otpError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  // Set OTP error inline
  void _setOtpError(String message) {
    setState(() {
      _otpError = message;
    });
  }

  // Set password error inline
  void _setPasswordError(String message) {
    setState(() {
      _passwordError = message;
    });
  }

  // Set confirm password error inline
  void _setConfirmPasswordError(String message) {
    setState(() {
      _confirmPasswordError = message;
    });
  }

  // ENHANCED: Granular password validation with specific rule feedback
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password';
    }

    List<String> violations = [];

    // Check each rule and collect violations
    if (password.length < 8) {
      violations.add('be at least 8 characters');
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      violations.add('include 1 uppercase letter');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      violations.add('include 1 number');
    }
    if (!RegExp(r'[!@#\$&*~]').hasMatch(password)) {
      violations.add('include 1 special character');
    }

    if (violations.isEmpty) {
      return null; // Password is valid
    }

    // Construct error message based on violations
    if (violations.length == 1) {
      return 'Password must ${violations.first}';
    } else if (violations.length == 2) {
      return 'Password must ${violations[0]} and ${violations[1]}';
    } else {
      // For 3+ violations, use comma separation with "and" before the last item
      String lastViolation = violations.removeLast();
      return 'Password must ${violations.join(', ')}, and $lastViolation';
    }
  }

  // Resend OTP with proper invalidation of old OTP
  Future<void> _resendOTP() async {
    if (resendSeconds > 0) return;

    setState(() {
      _isLoading = true;
      resendSeconds = 60;
    });

    try {
      await _authService.resendOTP(
        widget.email,
        userName: widget.email.split('@')[0],
      );

      if (mounted) {
        _startResendTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to resend code';

        if (e.toString().contains('Email sending timed out')) {
          errorMessage = 'Email sending timed out. Please check your internet connection';
        } else if (e.toString().contains('timeout') || e.toString().contains('network')) {
          errorMessage = 'Connection timeout. Please try again';
        } else if (e.toString().contains('Failed to send email')) {
          errorMessage = 'Failed to send verification email. Please try again';
        }

        _setOtpError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // OTP verification with automatic cleanup
  Future<void> _verifyOTP() async {
    _clearErrors();

    if (code.length != 5) {
      _setOtpError('Please enter the complete 5-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool isValid = await _authService.verifyOTP(widget.email, code).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Verification timed out. Please try again.');
        },
      );

      if (isValid && mounted) {
        setState(() {
          _isCodeVerified = true;
          _isLoading = false;
        });
        print('OTP verification successful - proceeding to password creation');
      } else if (mounted) {
        _setOtpError('Invalid verification code. Please try again');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Verification failed';

        if (e.toString().contains('timeout')) {
          errorMessage = 'Verification timed out. Please check your connection and try again';
        } else if (e.toString().contains('expired')) {
          errorMessage = 'Verification code has expired. Please request a new one';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Verification code not found. Please request a new one';
        } else if (e.toString().contains('No verification code found')) {
          errorMessage = 'Verification code not found. Please request a new one';
        }

        _setOtpError(errorMessage);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ENHANCED: Account creation with granular password validation
  Future<void> _createAccountWithPassword() async {
    _clearErrors();

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Use granular password validation
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      _setPasswordError(passwordError);
      return;
    }

    if (confirmPassword.isEmpty) {
      _setConfirmPasswordError('Please confirm your password');
      return;
    }

    if (password != confirmPassword) {
      _setConfirmPasswordError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        widget.email,
        _passwordController.text,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Account creation timed out. Please try again.');
        },
      );

      if (userCredential != null && mounted) {
        await _authService.saveUserToFirestore(
          userCredential.user!.uid,
          {
            'email': widget.email,
            'createdAt': DateTime.now().toIso8601String(),
            'isEmailVerified': true,
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Failed to save user data. Please try again.');
          },
        );

        _authService.deleteTemporaryOTP(widget.email).catchError((e) {
          print('OTP cleanup during account creation: $e');
        });

        print('Account created successfully for ${widget.email}');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Account creation failed';

        if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please check your internet connection and try again';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already registered. Please use a different email';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password is too weak. Please choose a stronger password';
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = 'Network error. Please check your internet connection';
        } else if (e.toString().contains('Failed to save user data')) {
          errorMessage = 'Account created but failed to save profile. Please try logging in';
        }

        _setPasswordError(errorMessage);
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
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UPDATED: Changed title and removed misleading email verification message
            Text(
              _isCodeVerified ? "Create Password" : "Verify Your Account",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            // Show verification form or password form
            _isCodeVerified ? _buildPasswordForm() : _buildVerificationForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter Verification Code",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'We sent a 5-digit verification code to ${widget.email}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
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
            activeColor: _otpError != null ? Colors.red : AppColors.secondary,
            inactiveColor: _otpError != null ? Colors.red : Colors.grey,
            selectedColor: AppColors.secondary,
          ),
          enableActiveFill: true,
          onChanged: (value) {
            code = value;
            if (_otpError != null) {
              setState(() {
                _otpError = null;
              });
            }
          },
          onCompleted: (value) {
            code = value;
          },
        ),

        // Inline error message for OTP
        if (_otpError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _otpError!,
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
            onPressed: code.length == 5 && !_isLoading ? _verifyOTP : null,
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

        const SizedBox(height: 16),

        // Resend timer/button
        Center(
          child: resendSeconds > 0
              ? Text(
            "Didn't get the code? Resend in ${resendSeconds}s",
            style: const TextStyle(color: Colors.grey),
          )
              : GestureDetector(
            onTap: _isLoading ? null : _resendOTP,
            child: const Text(
              "Didn't get the code? Resend now",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Create a strong password",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 16),

        // Password field with inline error
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.white),
              obscureText: _obscurePassword,
              onChanged: (_) => _clearErrors(),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: TextStyle(
                  color: _passwordError != null ? Colors.red : Colors.grey,
                ),
                filled: true,
                fillColor: const Color(0xFF1A2332),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _passwordError != null ? Colors.red : Colors.transparent,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _passwordError != null ? Colors.red : Colors.transparent,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _passwordError != null ? Colors.red : AppColors.secondary,
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),

            // Inline error message for password
            if (_passwordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  _passwordError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),

            // NEW: Static password requirements guide (always visible)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password must include:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRequirement('At least 8 characters'),
                  _buildRequirement('1 uppercase letter'),
                  _buildRequirement('1 number'),
                  _buildRequirement('1 special character (!@#\$&*~)'),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Confirm Password field with inline error
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _confirmPasswordController,
              style: const TextStyle(color: Colors.white),
              obscureText: _obscureConfirmPassword,
              onChanged: (_) => _clearErrors(),
              decoration: InputDecoration(
                labelText: "Confirm Password",
                labelStyle: TextStyle(
                  color: _confirmPasswordError != null ? Colors.red : Colors.grey,
                ),
                filled: true,
                fillColor: const Color(0xFF1A2332),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _confirmPasswordError != null ? Colors.red : Colors.transparent,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _confirmPasswordError != null ? Colors.red : Colors.transparent,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _confirmPasswordError != null ? Colors.red : AppColors.secondary,
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
            // Inline error message for confirm password
            if (_confirmPasswordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  _confirmPasswordError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 32),

        // Create Account Button
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
            onPressed: _isLoading ? null : _createAccountWithPassword,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
              "CREATE ACCOUNT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  // Helper widget for password requirements list
  Widget _buildRequirement(String requirement) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            requirement,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}