import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../LoginPages/login_page.dart';
import '../main_page.dart';
import '../color/colors.dart';
import '../services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF06111D),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // Check if user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          User user = snapshot.data!;

          // Check if email is verified for email/password users
          if (user.providerData.any((info) => info.providerId == 'password') && !user.emailVerified) {
            // Show email verification screen for email/password users only
            return const EmailVerificationScreen();
          } else {
            // User is verified or using social auth - check if onboarding is complete
            return const MainPageWrapper();
          }
        } else {
          // User is not signed in
          return const LoginPage();
        }
      },
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResendLoading = false;
  String? _errorMessage;
  Timer? _timer;
  Timer? _resendCooldownTimer;
  int _resendCooldownSeconds = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Get cooldown from backend and start timer
    _initializeCooldown();
    // Check email verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerificationStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCooldown() async {
    try {
      // Get remaining cooldown from backend
      final remainingCooldown = await _authService.getVerificationCooldown();
      if (mounted) {
        setState(() {
          _resendCooldownSeconds = remainingCooldown;
        });
        if (_resendCooldownSeconds > 0) {
          _startResendCooldown();
        }
      }
    } catch (e) {
      // If backend call fails, start with 0 (allow resend)
      if (mounted) {
        setState(() {
          _resendCooldownSeconds = 0;
        });
      }
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldownSeconds > 0) {
        setState(() {
          _resendCooldownSeconds--;
        });
      } else {
        timer.cancel();
        // Update UI one more time when timer reaches 0 to enable the button
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _checkEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified && mounted) {
        _timer?.cancel();
        // Email is verified, let AuthWrapper handle navigation
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    // Prevent resending if cooldown is active
    if (_resendCooldownSeconds > 0) {
      return;
    }

    setState(() => _isResendLoading = true);

    try {
      // Call backend function which enforces rate limiting
      final result = await _authService.resendVerificationEmail();

      if (result['success'] == true) {
        // Success - restart cooldown timer with backend-provided value
        final cooldown = result['remainingCooldownSeconds'] ?? 200;
        if (mounted) {
          setState(() {
            _resendCooldownSeconds = cooldown;
            _errorMessage = null;
          });
          if (_resendCooldownSeconds > 0) {
            _startResendCooldown();
          }
        }
      } else {
        // Rate limited or cooldown active
        final cooldown = result['remainingCooldownSeconds'] ?? 0;
        if (mounted) {
          setState(() {
            _resendCooldownSeconds = cooldown;
            _errorMessage = null; // Don't show error message for cooldown
          });
          if (_resendCooldownSeconds > 0) {
            _startResendCooldown();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to resend email. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isResendLoading = false);
    }
  }

  Future<void> _manualCheck() async {
    await _checkEmailVerificationStatus();

    if (mounted && !(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
      setState(() {
        _errorMessage = 'Email not verified yet';
      });
    }
  }

  Future<void> _signOut() async {
    _timer?.cancel();
    _resendCooldownTimer?.cancel();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification email to:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // I've Verified Button
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
                  onPressed: _manualCheck,
                  child: const Text(
                    "I'VE VERIFIED MY EMAIL",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Resend Email Button - shows only seconds countdown
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_isResendLoading || _resendCooldownSeconds > 0) ? null : _sendVerificationEmail,
                  child: _isResendLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _resendCooldownSeconds > 0
                        ? '$_resendCooldownSeconds'
                        : "RESEND VERIFICATION EMAIL",
                    style: TextStyle(
                      color: _resendCooldownSeconds > 0
                          ? AppColors.secondary.withOpacity(0.5)
                          : AppColors.secondary.withOpacity(0.8),
                      fontSize: _resendCooldownSeconds > 0 ? 32 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sign out button
              TextButton(
                onPressed: _signOut,
                child: Text(
                  'Use Different Account',
                  style: TextStyle(
                    color: AppColors.secondary.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}