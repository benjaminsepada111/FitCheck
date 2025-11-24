import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _retypeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureRetype = true;
  bool _isLoading = false;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _retypeController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _newController.text;
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
                color: isValid ? Colors.green : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if new password meets all requirements
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password does not meet all requirements'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if passwords match
    if (_newController.text != _retypeController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear fields and go back
        _currentController.clear();
        _newController.clear();
        _retypeController.clear();
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please log out and log in again before changing password';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection';
          break;
        default:
          message = 'Failed to change password: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
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
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Change Password"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _buildPasswordField(
                label: "Current Password",
                controller: _currentController,
                obscure: _obscureCurrent,
                toggle: () {
                  setState(() {
                    _obscureCurrent = !_obscureCurrent;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                label: "New Password",
                controller: _newController,
                obscure: _obscureNew,
                toggle: () {
                  setState(() {
                    _obscureNew = !_obscureNew;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
                    return 'Password does not meet all requirements';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Password validation indicators
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
              const SizedBox(height: 16),
              _buildPasswordField(
                label: "Re-type New Password",
                controller: _retypeController,
                obscure: _obscureRetype,
                toggle: () {
                  setState(() {
                    _obscureRetype = !_obscureRetype;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please re-type your new password';
                  }
                  if (value != _newController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isLoading ? null : _changePassword,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _isLoading ? Colors.grey : AppColors.secondary,
                    ),
                    child: Center(
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
                              "Confirm",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFD4E2EF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}
