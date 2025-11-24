import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../LoginPages/login_page.dart';
import '../color/colors.dart';
import '../services/user_time_tracker.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Widget _buildValidationItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isValid ? Colors.green : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isValid ? Colors.green : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to terms and conditions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create user account
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Save initial user data to Firestore
        try {
          await _authService.saveUserToFirestore(userCredential.user!.uid, {
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'photoURL': userCredential.user!.photoURL,
            'provider': 'email',
            'createdAt': DateTime.now().toIso8601String(),
            'isEmailVerified': false,
          });
        } catch (e) {
          // Log error but don't block signup - user document will be created later if needed
        }

        // Send verification email
        await userCredential.user!.sendEmailVerification();

        // Initialize time tracking for new user
        try {
          await UserTimeTracker.initializeUserStartDate();
        } catch (e) {
          // Don't block signup if time tracking fails
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please check your email to verify your account.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // Navigate back to auth wrapper which will show email verification screen
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak. Please use a stronger password.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = 'Failed to create account. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            FadePageRoute(
              page: const LoginPage(),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF06111D),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
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

                      // Create Account Title
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email Label
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Email field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            errorStyle: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 15),

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

                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
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
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
                              return 'Password does not meet all requirements';
                            }
                            return null;
                          },
                        ),
                      ),

                      // Password validation indicators (always visible)
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildValidationItem(
                              'Must have a minimum of 8 characters',
                              _hasMinLength,
                            ),
                            _buildValidationItem(
                              'Must include at least 1 uppercase character',
                              _hasUppercase,
                            ),
                            _buildValidationItem(
                              'Must include at least 1 lowercase character',
                              _hasLowercase,
                            ),
                            _buildValidationItem(
                              'Must include at least 1 number',
                              _hasNumber,
                            ),
                            _buildValidationItem(
                              'Must include at least one special character (!@#\$%^&* etc.)',
                              _hasSpecialChar,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Confirm Password Label
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Confirm Password field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
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
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF6B7280),
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms checkbox
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _agreeToTerms
                                    ? AppColors.secondary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _agreeToTerms
                                      ? AppColors.secondary
                                      : const Color(0xFF6B7280),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _agreeToTerms
                                  ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I agree to the Terms and Conditions',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // Create Account button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
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
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Login Link
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          FadePageRoute(
                            page: const LoginPage(),
                          ),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                            children: [
                              TextSpan(text: "Already have an account? "),
                              TextSpan(
                                text: "Login",
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
