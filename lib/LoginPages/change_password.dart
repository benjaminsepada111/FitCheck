import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'success.dart';
import '../color/colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  String? _oldPassError;
  String? _newPassStrength;
  String? _confirmPassError;

  void _validateInputs() {
    setState(() {
      // Old password check (for demo, assume "123456" is correct)
      _oldPassError = _oldPassController.text != "123456"
          ? "Incorrect password"
          : null;

      // New password strength check
      if (_newPassController.text.length < 6) {
        _newPassStrength = "Weak";
      } else if (_newPassController.text.length < 10) {
        _newPassStrength = "Fair";
      } else {
        _newPassStrength = "Strong";
      }

      // Confirm password check
      _confirmPassError =
      _newPassController.text != _confirmPassController.text
          ? "Password does not match"
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFF06111D),
      body: Stack(
        children: [
          // Background SVG
          Positioned(
            top: 0,
            left: -10,
            right: 175,
            child: SizedBox(
              height: 300,
              child: SvgPicture.asset("assets/login_svg/bg.svg"),
            ),
          ),
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  "Change Password",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  "Fill the form below to change your\npassword",
                  style: TextStyle(
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
              child: SvgPicture.asset("assets/login_svg/bg2.svg"),
            ),
          ),

          // Form container
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),

                  // OLD PASSWORD
                  _buildPasswordField(
                    label: "OLD PASSWORD",
                    controller: _oldPassController,
                    obscure: _oldObscure,
                    onToggle: () => setState(() => _oldObscure = !_oldObscure),
                    error: _oldPassError,
                    showWarningIcon: true,
                  ),
                  const SizedBox(height: 16),

                  // NEW PASSWORD
                  _buildPasswordField(
                    label: "NEW PASSWORD",
                    controller: _newPassController,
                    obscure: _newObscure,
                    onToggle: () => setState(() => _newObscure = !_newObscure),
                    strength: _newPassStrength,
                    showStrengthIcon: true,
                  ),
                  const SizedBox(height: 16),

                  // RE-TYPE PASSWORD
                  _buildPasswordField(
                    label: "RE-TYPE NEW PASSWORD",
                    controller: _confirmPassController,
                    obscure: _confirmObscure,
                    onToggle: () =>
                        setState(() => _confirmObscure = !_confirmObscure),
                    error: _confirmPassError,
                    showWarningIcon: true,
                  ),
                  const SizedBox(height: 32),

                  // Continue Button
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SuccessScreen()),
                        );
                      },
                      child: const Text(
                        "CONTINUE",
                        style: TextStyle(
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
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
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
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
                Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
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
                  const Icon(Icons.circle, color: Colors.orange, size: 10),
                const SizedBox(width: 4),
                Text(
                  strength,
                  style: TextStyle(
                    color: strength == "Strong"
                        ? Colors.green
                        : (strength == "Fair" ? Colors.orange : Colors.red),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
