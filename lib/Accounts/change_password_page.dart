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

  // Error messages for inline display
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _retypePasswordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_validatePassword);
    _currentController.addListener(() {
      setState(() {
        _currentPasswordError = null;
        _generalError = null;
      });
      // Trigger validation to clear errors
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
    });
    _newController.addListener(() {
      setState(() {
        _newPasswordError = null;
        _generalError = null;
      });
      // Trigger validation to clear errors and re-validate
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
    });
    _retypeController.addListener(() {
      setState(() {
        _retypePasswordError = null;
        _generalError = null;
      });
      // Trigger validation to clear errors and re-validate
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
    });
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
    // Clear previous errors
    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _retypePasswordError = null;
      _generalError = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      // Trigger validation again to show errors
      _formKey.currentState!.validate();
      return;
    }

    // Check if new password meets all requirements
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      setState(() {
        _newPasswordError = 'Password must meet all requirements listed below';
      });
      // Trigger validation to show the error
      _formKey.currentState!.validate();
      return;
    }

    // Check if new password is different from current password
    if (_currentController.text == _newController.text) {
      setState(() {
        _newPasswordError = 'New password must be different from your current password';
      });
      // Trigger validation to show the error
      _formKey.currentState!.validate();
      return;
    }

    // Check if passwords match
    if (_newController.text != _retypeController.text) {
      setState(() {
        _retypePasswordError = 'Passwords do not match. Please re-enter your new password';
      });
      // Trigger validation to show the error
      _formKey.currentState!.validate();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _generalError = 'You must be logged in to change your password';
          _isLoading = false;
        });
        return;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentController.text,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (authError) {
        // Handle re-authentication errors specifically
        if (authError.code == 'wrong-password' || 
            authError.code == 'invalid-credential' ||
            authError.code == 'invalid-password' ||
            authError.code == 'user-mismatch') {
          setState(() {
            _currentPasswordError = 'The current password you entered is incorrect';
          });
          // Trigger validation to show the error
          if (_formKey.currentState != null) {
            _formKey.currentState!.validate();
          }
          return;
        }
        // Re-throw if it's a different auth error
        rethrow;
      }

      // Update password
      await user.updatePassword(_newController.text);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
        case 'invalid-credential':
        case 'invalid-password':
          message = 'The current password you entered is incorrect';
          setState(() {
            _currentPasswordError = message;
          });
          // Trigger validation to show the error
          if (_formKey.currentState != null) {
            _formKey.currentState!.validate();
          }
          break;
        case 'weak-password':
          message = 'The new password is too weak. Please choose a stronger password';
          setState(() {
            _newPasswordError = message;
          });
          // Trigger validation to show the error
          if (_formKey.currentState != null) {
            _formKey.currentState!.validate();
          }
          break;
        case 'requires-recent-login':
          message = 'For security, please log out and log back in before changing your password';
          setState(() {
            _generalError = message;
          });
          break;
        case 'network-request-failed':
          message = 'Unable to connect. Please check your internet connection and try again';
          setState(() {
            _generalError = message;
          });
          break;
        default:
          // Log the actual error code for debugging
          debugPrint('FirebaseAuthException code: ${e.code}, message: ${e.message}');
          message = 'Unable to change password. Please try again later';
          setState(() {
            _generalError = message;
          });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Unexpected error: $e');
        setState(() {
          _generalError = 'An unexpected error occurred. Please try again';
        });
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
              // General error banner
              if (_generalError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _generalError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildPasswordField(
                label: "Current Password",
                controller: _currentController,
                obscure: _obscureCurrent,
                toggle: () {
                  setState(() {
                    _obscureCurrent = !_obscureCurrent;
                  });
                },
                errorText: _currentPasswordError,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  if (_currentPasswordError != null) {
                    return _currentPasswordError;
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
                errorText: _newPasswordError,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  // Check if custom error is set (from _changePassword)
                  if (_newPasswordError != null) {
                    return _newPasswordError;
                  }
                  // Check if password is different from current
                  if (value == _currentController.text && _currentController.text.isNotEmpty) {
                    return 'New password must be different from your current password';
                  }
                  // Check password requirements (only show if user has typed something)
                  if (value.isNotEmpty && (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar)) {
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
                errorText: _retypePasswordError,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please re-type your new password';
                  }
                  // Check if custom error is set (from _changePassword)
                  if (_retypePasswordError != null) {
                    return _retypePasswordError;
                  }
                  // Check if passwords match
                  if (value != _newController.text && _newController.text.isNotEmpty) {
                    return 'Passwords do not match. Please re-enter your new password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
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
    String? errorText,
  }) {
    final hasError = errorText != null;
    
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
          validator: (value) {
            // First run the custom validator if provided
            final validatorError = validator?.call(value);
            // If there's a custom errorText, use that instead
            if (errorText != null) {
              return errorText;
            }
            return validatorError;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.secondary,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.secondary,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.secondary,
                width: 2,
              ),
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
