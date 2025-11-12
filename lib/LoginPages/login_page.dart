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
import '../utils/page_transitions.dart';

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
  String? _socialError;

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

  // Email/Password Login
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
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

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    _clearErrors();

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Google sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
          return;
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'An account already exists with this email using a different sign-in method';
        } else if (e.toString().contains('popup-closed-by-user')) {
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

  // Apple Sign In
  Future<void> _signInWithApple() async {
    _clearErrors();

    if (!Platform.isIOS) {
      _setSocialError('Apple Sign In is only available on iOS devices');
      return;
    }

    setState(() {
      _isAppleLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithApple();

      if (userCredential != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Apple sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
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

  // Facebook Sign In
  Future<void> _signInWithFacebook() async {
    _clearErrors();

    setState(() {
      _isFacebookLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithFacebook();

      if (userCredential != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Facebook sign-in failed';

        if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
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
      backgroundColor: const Color(0xFF06111D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 30),

                // FITCHECK Logo
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(
                        text: 'Fit',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'Check',
                        style: TextStyle(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Log In Title
                const Text(
                  'Log In',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // General Error Display
                if (_generalError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _generalError!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Social Error Display
                if (_socialError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _socialError!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email or Phone Number Label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Email or Phone Number',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Email TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _emailError != null
                          ? Colors.red
                          : Colors.transparent,
                    ),
                  ),
                  child: TextField(
                    controller: _emailController,
                    onChanged: (_) => _clearErrors(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Email or Phone Number',
                      hintStyle: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      errorText: null,
                    ),
                  ),
                ),

                if (_emailError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _emailError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Password Label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Password TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _passwordError != null
                          ? Colors.red
                          : Colors.transparent,
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    onChanged: (_) => _clearErrors(),
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF6B7280),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      errorText: null,
                    ),
                  ),
                ),

                if (_passwordError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Keep me logged in & Forgot Password Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _rememberMe
                                  ? AppColors.secondary
                                  : Colors.transparent,
                              border: Border.all(
                                color: _rememberMe
                                    ? AppColors.secondary
                                    : const Color(0xFF6B7280),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _rememberMe
                                ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Keep me logged in',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: const ForgotPasswordPage(),
                            direction: AxisDirection.right,
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // Log In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _loginWithEmailPassword,
                    child: _isLoading
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Text(
                      'Log In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // "or" Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Social Login Buttons (Full-Width with Labels)
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
                          size: 30,
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

                const SizedBox(height: 18),

                // Sign Up Link
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      SlidePageRoute(
                        page: const SignUpPage(),
                        direction: AxisDirection.right,
                      ),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      children: [
                        TextSpan(text: "Don't you have an account? "),
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
    );
  }
}