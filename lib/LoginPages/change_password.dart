// lib/LoginPages/change_password.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../color/colors.dart';
import '../services/forgot_password_service.dart.dart';
import '../LoginPages/login_page.dart';

class WorkingChangePasswordPage extends StatefulWidget {
  final String? email;
  final bool isCurrentUser;
  final bool isVerified;

  const WorkingChangePasswordPage({
    super.key,
    this.email,
    this.isCurrentUser = false,
    this.isVerified = false,
  });

  @override
  State<WorkingChangePasswordPage> createState() => _WorkingChangePasswordPageState();
}

class _WorkingChangePasswordPageState extends State<WorkingChangePasswordPage> {
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();

  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isLoading = false;
  bool _isFirebaseUser = false;

  // Error states for inline display
  String? _oldPassError;
  String? _newPassError;
  String? _confirmPassError;
  String? _generalError;

  // Password strength indicator
  String? _newPassStrength;

  @override
  void initState() {
    super.initState();
    _checkIfFirebaseUser();
  }

  void _checkIfFirebaseUser() async {
    if (widget.email != null) {
      _isFirebaseUser = await _forgotPasswordService.isFirebaseUser(widget.email!);
      setState(() {});
    } else if (widget.isCurrentUser) {
      _isFirebaseUser = FirebaseAuth.instance.currentUser != null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // Clear errors
  void _clearErrors() {
    setState(() {
      _oldPassError = null;
      _newPassError = null;
      _confirmPassError = null;
      _generalError = null;
    });
  }

  // Set specific field errors
  void _setOldPassError(String message) {
    setState(() {
      _oldPassError = message;
      _generalError = null;
    });
  }

  void _setNewPassError(String message) {
    setState(() {
      _newPassError = message;
      _generalError = null;
    });
  }

  void _setConfirmPassError(String message) {
    setState(() {
      _confirmPassError = message;
      _generalError = null;
    });
  }

  void _setGeneralError(String message) {
    setState(() {
      _generalError = message;
      _oldPassError = null;
      _newPassError = null;
      _confirmPassError = null;
    });
  }

  // Validate inputs and set errors inline
  void _validateInputs() {
    _clearErrors();

    // Old password validation
    if (widget.isCurrentUser || (!widget.isVerified && _isFirebaseUser)) {
      if (_oldPassController.text.isEmpty) {
        _setOldPassError("Please enter your current password");
        return;
      }
    }

    // New password validation
    final newPass = _newPassController.text;
    if (newPass.isEmpty) {
      _setNewPassError("Please enter a new password");
      return;
    }

    if (newPass.length < 6) {
      _setNewPassError("Password must be at least 6 characters");
      return;
    }

    // Confirm password validation
    if (_confirmPassController.text.isEmpty) {
      _setConfirmPassError("Please confirm your password");
      return;
    }

    if (newPass != _confirmPassController.text) {
      _setConfirmPassError("Passwords do not match");
      return;
    }
  }

  // Update password strength indicator
  void _updatePasswordStrength(String password) {
    setState(() {
      if (password.isEmpty) {
        _newPassStrength = null;
      } else if (password.length < 6) {
        _newPassStrength = "Weak - Too short";
      } else if (password.length < 8) {
        _newPassStrength = "Fair - Add more characters";
      } else if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
        _newPassStrength = "Fair - Add numbers and mixed case";
      } else {
        _newPassStrength = "Strong";
      }
    });
  }

  // Change password - REFACTORED with correct method names
  Future<void> _changePassword() async {
    _validateInputs();

    // If there are validation errors, don't proceed
    if (_oldPassError != null || _newPassError != null || _confirmPassError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isCurrentUser) {
        // Current user changing password - use correct method name
        final success = await _forgotPasswordService.changePasswordForLoggedInUser(
          _oldPassController.text,
          _newPassController.text,
        );

        if (success && mounted) {
          // Navigate directly to login page with inline success banner
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPageWithSuccessBanner(
                successMessage: "Password updated successfully! Please sign in with your new password.",
              ),
            ),
                (route) => false,
          );
        }
      } else if (widget.isVerified) {
        // Verified user (through forgot password flow) - use correct method name
        final result = await _forgotPasswordService.changePassword(
          widget.email!,
          _newPassController.text,
        );

        if (result['success'] && mounted) {
          if (result['method'] == 'firebase_email') {
            // Firebase user - show them they need to check email
            _setGeneralError("Please check your email and click the Firebase reset link to complete password change");
          } else {
            // Navigate directly to login page with inline success banner
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPageWithSuccessBanner(
                  successMessage: "Password updated successfully! Please sign in with your new password.",
                ),
              ),
                  (route) => false,
            );
          }
        } else if (mounted) {
          _setGeneralError("Failed to update password. Please try again");
        }
      } else if (_isFirebaseUser) {
        // Firebase user without verification - use the logged in user method
        final success = await _forgotPasswordService.changePasswordForLoggedInUser(
          _oldPassController.text,
          _newPassController.text,
        );

        if (success && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPageWithSuccessBanner(
                successMessage: "Password updated successfully! Please sign in with your new password.",
              ),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        if (errorMessage.contains('Current password is incorrect')) {
          _setOldPassError("Current password is incorrect");
        } else if (errorMessage.contains('weak-password') || errorMessage.contains('too weak')) {
          _setNewPassError("Password is too weak. Please choose a stronger password");
        } else if (errorMessage.contains('requires-recent-login')) {
          _setGeneralError("For security reasons, please sign out and sign back in before changing your password");
        } else if (errorMessage.contains('network')) {
          _setGeneralError("Network error. Please check your connection");
        } else if (errorMessage.contains('Failed to change password')) {
          _setGeneralError(errorMessage);
        } else {
          _setGeneralError("Failed to update password. Please try again");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Change Password",
          style: TextStyle(color: Colors.white),
        ),
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
            // Success message if user came from verification
            if (widget.isVerified)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
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
                        'Email verified successfully! Now create your new password.',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // General error message
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

            // Old password field (if required)
            if (widget.isCurrentUser || (!widget.isVerified && _isFirebaseUser))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordField(
                    label: "Current Password",
                    controller: _oldPassController,
                    obscure: _oldObscure,
                    onToggle: () => setState(() => _oldObscure = !_oldObscure),
                    error: _oldPassError,
                    onChanged: (_) => _clearErrors(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // New password field
            _buildPasswordField(
              label: "New Password",
              controller: _newPassController,
              obscure: _newObscure,
              onToggle: () => setState(() => _newObscure = !_newObscure),
              error: _newPassError,
              strengthIndicator: _newPassStrength,
              onChanged: (value) {
                _clearErrors();
                _updatePasswordStrength(value);
              },
            ),

            const SizedBox(height: 16),

            // Confirm password field
            _buildPasswordField(
              label: "Confirm New Password",
              controller: _confirmPassController,
              obscure: _confirmObscure,
              onToggle: () => setState(() => _confirmObscure = !_confirmObscure),
              error: _confirmPassError,
              onChanged: (_) => _clearErrors(),
            ),

            const SizedBox(height: 32),

            // Change Password Button
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
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  widget.isCurrentUser
                      ? "UPDATE PASSWORD"
                      : "CHANGE PASSWORD",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? error,
    String? strengthIndicator,
    void Function(String)? onChanged,
  }) {
    Color strengthColor = Colors.grey;
    if (strengthIndicator != null) {
      if (strengthIndicator.startsWith("Weak")) {
        strengthColor = Colors.red;
      } else if (strengthIndicator.startsWith("Fair")) {
        strengthColor = Colors.orange;
      } else if (strengthIndicator.startsWith("Strong")) {
        strengthColor = Colors.green;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          obscureText: obscure,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: error != null ? Colors.red : Colors.grey,
            ),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? Colors.red : AppColors.secondary,
                width: 2,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
          ),
        ),

        // Error message
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),

        // Strength indicator
        if (strengthIndicator != null && error == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              strengthIndicator,
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// Enhanced Login Page with success banner
class LoginPageWithSuccessBanner extends StatelessWidget {
  final String successMessage;

  const LoginPageWithSuccessBanner({
    super.key,
    required this.successMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      body: Column(
        children: [
          // Success banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 50),
            color: AppColors.secondary.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    successMessage,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.secondary),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Regular login page content
          const Expanded(
            child: LoginPage(),
          ),
        ],
      ),
    );
  }
}