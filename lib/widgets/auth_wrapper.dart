import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../LoginPages/login_page.dart';
import '../main_page.dart';
import '../color/colors.dart';

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

  @override
  void initState() {
    super.initState();
    // Check email verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerificationStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    setState(() => _isResendLoading = true);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://capstone-project-a9296.firebaseapp.com/__/auth/action?mode=verifyEmail',
          handleCodeInApp: false,
          androidPackageName: 'com.example.capstone_project',
          androidInstallApp: false,
          iOSBundleId: 'com.example.capstoneProject',
        ),
      );
      // No popup notification - just clear any error message
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    } catch (e) {
      // No popup - silently handle error
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
              const SizedBox(height: 24),
              const Text(
                'Please check your email and click the verification link, then come back and tap "I\'ve Verified"',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
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

              // Resend Email Button
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
                  onPressed: _isResendLoading ? null : _sendVerificationEmail,
                  child: _isResendLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    "RESEND VERIFICATION EMAIL",
                    style: TextStyle(
                      color: AppColors.secondary.withOpacity(0.8),
                      fontSize: 16,
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