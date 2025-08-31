import 'package:flutter/material.dart';
import 'continue_with_email.dart';

class CreateAccountPage extends StatelessWidget {
  const CreateAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create new account",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Small text
            const Text(
              "",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            // Continue with Email button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEmailScreen()),
                  );
                },
                child: const Text("Continue with Email"),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              "or",
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Facebook button
            _socialButton(
              icon: Icons.facebook,
              text: "Continue with Facebook",
              onPressed: () {},
            ),

            const SizedBox(height: 12),

            // Google button
            _socialButton(
              image:
                  "https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png",
              text: "Continue with Google",
              onPressed: () {},
            ),

            const SizedBox(height: 12),

            // Apple button
            _socialButton(
              icon: Icons.apple,
              text: "Continue with Apple",
              onPressed: () {},
            ),
            const SizedBox(height: 10),
            // Already have account? Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? "),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, "/login");
                  },
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),

            // Terms and Privacy
            const Text.rich(
              TextSpan(
                text: "By using Classroom, you agree to the ",
                style: TextStyle(fontSize: 10, color: Colors.black54),
                children: [
                  TextSpan(
                    text: "Terms",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Reusable social button
  Widget _socialButton({
    IconData? icon,
    String? image,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: image == null
            ? Icon(icon, size: 20)
            : Image.network(image, height: 20),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
