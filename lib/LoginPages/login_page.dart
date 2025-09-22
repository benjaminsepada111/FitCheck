// lib/LoginPages/login_page.dart - Enhanced with Social Auth
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../UserInputFile/onboarding_screen.dart';
import 'forgot_password.dart';
import 'package:capstone_project/SignUpPages/signuppage.dart';
import '../app_text_styles.dart';
import '../color/colors.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isFacebookLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  // Error states for inline display
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  String? _socialError; // For social authentication errors

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Clear errors when user starts typing
  void _clearErrors() {
    if (_emailError != null || _passwordError != null || _generalError != null || _socialError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
        _generalError = null;
        _socialError = null;
      });
    }
  }

  // Set email error inline
  void _setEmailError(String message) {
    setState(() {
      _emailError = message;
      _generalError = null;
      _socialError = null;
    });
  }

  // Set password error inline
  void _setPasswordError(String message) {
    setState(() {
      _passwordError = message;
      _generalError = null;
      _socialError = null;
    });
  }

  // Set general error (for auth failures)
  void _setGeneralError(String message) {
    setState(() {
      _generalError = message;
      _emailError = null;
      _passwordError = null;
      _socialError = null;
    });
  }

  // Set social authentication error
  void _setSocialError(String message) {
    setState(() {
      _socialError = message;
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });
  }

  // Email/Password Login - REFACTORED
  Future<void> _loginWithEmailPassword() async {
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

    // Validate password field
    final password = _passwordController.text;
    if (password.isEmpty) {
      _setPasswordError('Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (userCredential != null && mounted) {
        // Navigate directly to main app - NO SUCCESS MESSAGE
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        switch (e.code) {
          case 'user-not-found':
            _setEmailError('No account found with this email address');
            break;
          case 'wrong-password':
            _setPasswordError('Incorrect password. Please try again');
            break;
          case 'invalid-email':
            _setEmailError('Invalid email address format');
            break;
          case 'user-disabled':
            _setGeneralError('This account has been disabled');
            break;
          case 'too-many-requests':
            _setGeneralError('Too many failed attempts. Please try again later');
            break;
          case 'invalid-credential':
            _setGeneralError('Invalid email or password. Please check your credentials');
            break;
          default:
            _setGeneralError('Login failed. Please try again');
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('network')) {
          _setGeneralError('Network error. Please check your internet connection');
        } else {
          _setGeneralError('An unexpected error occurred. Please try again');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google Sign In - REFACTORED
  Future<void> _signInWithGoogle() async {
    _clearErrors();

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null && mounted) {
        // Navigate directly to main app - NO SUCCESS MESSAGE
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
              (route) => false,
        );
      }
      // If userCredential is null, user cancelled - no error to show
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Google sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
          // User cancelled - no error message needed
          return;
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'An account already exists with this email using a different sign-in method';
        } else if (e.toString().contains('popup-closed-by-user')) {
          // User closed popup - no error message needed
          return;
        }

        _setSocialError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // Apple Sign In - REFACTORED
  Future<void> _signInWithApple() async {
    _clearErrors();

    if (!Platform.isIOS) {
      _setSocialError('Apple sign-in is only available on iOS devices');
      return;
    }

    setState(() {
      _isAppleLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithApple();

      if (userCredential != null && mounted) {
        // Navigate directly to main app - NO SUCCESS MESSAGE
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
              (route) => false,
        );
      }
      // If userCredential is null, user cancelled - no error to show
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Apple sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
          // User cancelled - no error message needed
          return;
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'An account already exists with this email using a different sign-in method';
        }

        _setSocialError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  // Facebook Sign In - REFACTORED
  Future<void> _signInWithFacebook() async {
    _clearErrors();

    setState(() {
      _isFacebookLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithFacebook();

      if (userCredential != null && mounted) {
        // Navigate directly to main app - NO SUCCESS MESSAGE
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
              (route) => false,
        );
      }
      // If userCredential is null, user cancelled - no error to show
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Facebook sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
          // User cancelled - no error message needed
          return;
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'An account already exists with this email using a different sign-in method';
        }

        _setSocialError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFacebookLoading = false;
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

          // Title and subtitle
          const Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Sign in to your account",
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General error message (for auth failures)
                  if (_generalError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _generalError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Social error message (for social auth failures)
                  if (_socialError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _socialError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  const SizedBox(height: 16),

                  // Password TextField with inline error
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
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Remember me and forgot password row
                  Row(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: AppColors.secondary,
                            checkColor: Colors.white,
                          ),
                          const Text(
                            "Remember me",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Sign In Button
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
                      onPressed: _isLoading ? null : _loginWithEmailPassword,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "SIGN IN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Or continue with",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Social login buttons
                  Column(
                    children: [
                      // Google Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isGoogleLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : SvgPicture.asset(
                            "assets/login_svg/google.svg",
                            height: 24,
                          ),
                          label: const Text(
                            "Continue with Google",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Apple Sign In button (iOS only)
                      if (Platform.isIOS)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isAppleLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons.apple,
                              color: Colors.white,
                              size: 24,
                            ),
                            label: const Text(
                              "Continue with Apple",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: _isAppleLoading ? null : _signInWithApple,
                          ),
                        ),

                      if (Platform.isIOS) const SizedBox(height: 12),

                      // Facebook Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isFacebookLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(
                            Icons.facebook,
                            color: Colors.blue,
                            size: 24,
                          ),
                          label: const Text(
                            "Continue with Facebook",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: _isFacebookLoading ? null : _signInWithFacebook,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Sign Up",
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

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}