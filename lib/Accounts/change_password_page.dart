import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _retypeController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = false; // 👈 matches screenshot (new password visible)
  bool _obscureRetype = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        centerTitle: true,
        elevation: 0,

        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
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
                onPressed: () {
                  // TODO: Implement password update logic
                },
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                   color: AppColors.secondary,
                  ),
                  child: const Center(
                    child: Text(
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
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
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
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFD4E2EF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
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
