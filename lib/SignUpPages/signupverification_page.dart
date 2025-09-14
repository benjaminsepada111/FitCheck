import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:capstone_project/color/colors.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'dart:math';

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

  void _showErrorDialog(String message) {
    if (!mounted) return;
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

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Created Successfully!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.secondary,
            ),
            SizedBox(height: 16),
            Text(
              'Your account has been created and verified successfully.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
              // Navigate to main app or login page
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOTP() async {
    if (code.length != 5) {
      _showErrorDialog('Please enter the complete 5-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verify OTP with timeout
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
      } else if (mounted) {
        _showErrorDialog('Invalid verification code. Please try again.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Verification failed.';

        if (e.toString().contains('timeout')) {
          errorMessage = 'Verification timed out. Please check your internet connection and try again.';
        } else if (e.toString().contains('expired')) {
          errorMessage = 'Verification code has expired. Please request a new one.';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Verification code not found. Please request a new one.';
        }

        _showErrorDialog(errorMessage);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createAccountWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create Firebase Auth user with timeout
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
        // Save user data to Firestore with timeout
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

        // Clean up temporary OTP (don't await to avoid blocking)
        _authService.deleteTemporaryOTP(widget.email).catchError((e) {
          // Ignore cleanup errors
          print('Failed to cleanup OTP: $e');
        });

        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Account creation failed.';

        if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please check your internet connection and try again.';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already registered. Please use a different email.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password is too weak. Please choose a stronger password.';
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = 'Network error. Please check your internet connection.';
        }

        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Generate new OTP for resend
  String _generateOTP() {
    Random random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  Future<void> _resendOTP() async {
    if (resendSeconds > 0) return;

    setState(() {
      _isLoading = true;
      resendSeconds = 60;
    });

    try {
      // Generate new OTP
      String newOTP = _generateOTP();

      // Store new OTP in Firestore with timeout
      await _authService.storeTemporaryOTP(widget.email, newOTP).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );

      // In production, send the actual email here
      print('New OTP sent to ${widget.email}: $newOTP'); // For testing

      if (mounted) {
        _startResendTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to resend code.';

        if (e.toString().contains('timeout') || e.toString().contains('network')) {
          errorMessage = 'Connection timeout. Please check your internet connection and try again.';
        }

        _showErrorDialog(errorMessage);
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

          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isCodeVerified ? "Create Password" : "Verification",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isCodeVerified
                      ? "Create a secure password for your account"
                      : "We have sent a code to your email\n${widget.email}",
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

          // Content
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _isCodeVerified ? _buildPasswordForm() : _buildVerificationForm(),
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

  Widget _buildVerificationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),

        // Code input label
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "VERIFICATION CODE",
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
            // Auto-verify when complete
            if (!_isLoading) {
              _verifyOTP();
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
            onPressed: _isLoading || code.length != 5 ? null : _verifyOTP,
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
        resendSeconds > 0
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

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Success message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.secondary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Email verified successfully! Now create your password.',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Password field
          const Text(
            "PASSWORD",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: "Enter your password",
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm Password field
          const Text(
            "CONFIRM PASSWORD",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: "Confirm your password",
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

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

          const SizedBox(height: 50),
        ],
      ),
    );
  }
}