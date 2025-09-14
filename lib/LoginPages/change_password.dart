import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'success.dart';
import '../color/colors.dart';
import '../services/forgot_password_service.dart.dart'; // Updated service

class WorkingChangePasswordPage extends StatefulWidget {
  final String? email;
  final bool isVerified;
  final bool isCurrentUser;

  const WorkingChangePasswordPage({
    super.key,
    this.email,
    this.isVerified = false,
    this.isCurrentUser = false,
  });

  @override
  State<WorkingChangePasswordPage> createState() => _WorkingChangePasswordPageState();
}

class _WorkingChangePasswordPageState extends State<WorkingChangePasswordPage> {
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final ForgotPasswordService _forgotPasswordService = ForgotPasswordService();
  final _formKey = GlobalKey<FormState>();

  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isLoading = false;
  bool _isFirebaseUser = false;

  String? _oldPassError;
  String? _newPassStrength;
  String? _confirmPassError;

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

  void _showErrorDialog(String message) {
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  void _showOptionsDialog(String title, String message, VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onProceed();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _validateInputs() {
    setState(() {
      // Old password validation
      if (widget.isCurrentUser || (!widget.isVerified && _isFirebaseUser)) {
        _oldPassError = _oldPassController.text.isEmpty
            ? "Please enter your current password"
            : null;
      }

      // New password strength check
      final newPass = _newPassController.text;
      if (newPass.isEmpty) {
        _newPassStrength = null;
      } else if (newPass.length < 6) {
        _newPassStrength = "Weak - Too short";
      } else if (newPass.length < 8) {
        _newPassStrength = "Fair - Add more characters";
      } else if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(newPass)) {
        _newPassStrength = "Fair - Add numbers and mixed case";
      } else {
        _newPassStrength = "Strong";
      }

      // Confirm password check
      _confirmPassError = _newPassController.text != _confirmPassController.text
          ? "Passwords do not match"
          : null;
    });
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _newPassController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if ((widget.isCurrentUser || (!widget.isVerified && _isFirebaseUser)) &&
        (value == null || value.isEmpty)) {
      return 'Please enter your current password';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      _validateInputs();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isCurrentUser) {
        // Current logged-in user changing password - THIS ACTUALLY WORKS
        await _forgotPasswordService.changePasswordForLoggedInUser(
          _oldPassController.text,
          _newPassController.text,
        );

        _showSuccessMessage('Password updated successfully!');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SuccessScreen()),
                (route) => false,
          );
        }
      } else if (widget.isVerified && widget.email != null) {
        // Password reset flow from forgot password
        final result = await _forgotPasswordService.changePassword(
          widget.email!,
          _newPassController.text,
        );

        if (result['success']) {
          if (result['method'] == 'firebase_email') {
            // Firebase user - direct them to email
            _showOptionsDialog(
                'Check Your Email',
                'We\'ve sent a password reset link to ${widget.email}. Please check your email and click the link to complete your password change.\n\nAlternatively, you can try logging in - Firebase may have already updated your password.',
                    () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SuccessScreen()),
                        (route) => false,
                  );
                }
            );
          } else {
            // Demo user or successful change
            _showSuccessMessage(result['message']);

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SuccessScreen()),
                    (route) => false,
              );
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          setState(() {
            _oldPassError = 'Incorrect current password';
          });
          break;
        case 'weak-password':
          _showErrorDialog('Password is too weak. Please choose a stronger password.');
          break;
        case 'requires-recent-login':
          _showErrorDialog('For security, please log out and log back in before changing your password.');
          break;
        default:
          _showErrorDialog('Failed to change password: ${e.message}');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background SVG
          Positioned(
            top: 0,
            left: -10,
            right: 175,
            child: SizedBox(
              height: 300,
              child: SvgPicture.asset(
                "assets/login_svg/bg.svg",
                color: AppColors.secondary,
              ),
            ),
          ),

          // Title and subtitle
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Change Password",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isCurrentUser
                      ? "Update your current password securely"
                      : (_isFirebaseUser
                      ? "Update your Firebase account password"
                      : "Set your new password"),
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
              height: 200,
              child: SvgPicture.asset(
                "assets/login_svg/bg2.svg",
                color: AppColors.secondary,
              ),
            ),
          ),

          // Form container
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),

                      // Status indicator
                      if (widget.isCurrentUser || _isFirebaseUser)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  widget.isCurrentUser ? Icons.person : Icons.verified_user,
                                  color: AppColors.secondary,
                                  size: 20
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.isCurrentUser
                                      ? "Logged-in User - Direct password update"
                                      : "Firebase Account - Secure password change",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (widget.isCurrentUser || _isFirebaseUser) const SizedBox(height: 16),

                      // CURRENT PASSWORD (show for logged-in user or Firebase user requiring re-auth)
                      if (widget.isCurrentUser || (!widget.isVerified && _isFirebaseUser)) ...[
                        _buildPasswordField(
                          label: "CURRENT PASSWORD",
                          controller: _oldPassController,
                          obscure: _oldObscure,
                          onToggle: () => setState(() => _oldObscure = !_oldObscure),
                          validator: _validateCurrentPassword,
                          error: _oldPassError,
                          showWarningIcon: true,
                          onChanged: (_) => _validateInputs(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // NEW PASSWORD
                      _buildPasswordField(
                        label: "NEW PASSWORD",
                        controller: _newPassController,
                        obscure: _newObscure,
                        onToggle: () => setState(() => _newObscure = !_newObscure),
                        validator: _validateNewPassword,
                        strength: _newPassStrength,
                        showStrengthIcon: true,
                        onChanged: (_) => _validateInputs(),
                      ),
                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      _buildPasswordField(
                        label: "CONFIRM NEW PASSWORD",
                        controller: _confirmPassController,
                        obscure: _confirmObscure,
                        onToggle: () =>
                            setState(() => _confirmObscure = !_confirmObscure),
                        validator: _validateConfirmPassword,
                        error: _confirmPassError,
                        showWarningIcon: true,
                        onChanged: (_) => _validateInputs(),
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? error,
    String? strength,
    bool showWarningIcon = false,
    bool showStrengthIcon = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          enabled: !_isLoading,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
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
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                if (showWarningIcon)
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (strength != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                if (showStrengthIcon)
                  Icon(
                    Icons.circle,
                    color: _getStrengthColor(strength),
                    size: 10,
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    strength,
                    style: TextStyle(
                      color: _getStrengthColor(strength),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getStrengthColor(String strength) {
    if (strength.contains("Strong")) {
      return Colors.green;
    } else if (strength.contains("Fair")) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}