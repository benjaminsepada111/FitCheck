import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AddEmailScreen(),
    );
  }
}

// ---------------- STEP 1: Add Email ----------------
class AddEmailScreen extends StatelessWidget {
  const AddEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black), // back arrow
        title: const Text(
          "Add your email", // ✅ Your text here
          style: TextStyle(
            color: Colors.black, // make it black to match your theme
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StepProgress(currentStep: 1),
            const SizedBox(height: 30),
            const Text(
              "Email",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VerifyEmailScreen(email: emailController.text),
                  ),
                );
              },
              child: const Text(
                "Confirm Email",
                style: TextStyle(fontSize: 16),
              ),
            ),
            const Spacer(),
            const Center(
              child: Text(
                "By using Classroom, you agree to the Terms and Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- STEP 2: Verify Email ----------------
class VerifyEmailScreen extends StatelessWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final codeControllers = List.generate(5, (_) => TextEditingController());

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black), // back arrow
        title: const Text(
          "Verify Email", // ✅ Your text here
          style: TextStyle(
            color: Colors.black, // make it black to match your theme
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const StepProgress(currentStep: 2),
            const SizedBox(height: 30),
            Text(
              "Verify Email",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text(
              "We just sent 5-digit code to $email, enter it below:",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                return SizedBox(
                  width: 50,
                  child: TextField(
                    controller: codeControllers[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: "",
                      border: OutlineInputBorder(),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePasswordScreen(),
                  ),
                );
              },
              child: const Text("Continue", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {},
              child: const Text("Didn’t receive a code? Resend"),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- STEP 3: Create Password ----------------
class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool get hasMinLength => passwordController.text.length >= 8;
  bool get hasUpper => passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get hasLower => passwordController.text.contains(RegExp(r'[a-z]'));
  bool get hasNumber => passwordController.text.contains(RegExp(r'[0-9]'));
  bool get hasSpecial =>
      passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  // ✅ Calculate password strength score
  double get passwordStrength {
    int strength = 0;
    if (hasMinLength) strength++;
    if (hasUpper) strength++;
    if (hasLower) strength++;
    if (hasNumber) strength++;
    if (hasSpecial) strength++;
    return strength / 5; // Value between 0.0 and 1.0
  }

  // ✅ Change progress bar color based on strength
  Color get strengthColor {
    if (passwordStrength <= 0.3) return Colors.red;
    if (passwordStrength <= 0.6) return Colors.orange;
    return Colors.green;
  }

  // ✅ Change strength text based on score
  String get strengthText {
    if (passwordStrength <= 0.3) return "Weak";
    if (passwordStrength <= 0.6) return "Fair";
    return "Strong";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true, // ✅ UI moves up when keyboard appears (fixes bottom overflow)
      appBar: AppBar(
        leading: const BackButton(color: Colors.black), // back arrow
        title: const Text(
          "Create Password", // ✅ Your text here
          style: TextStyle(
            color: Colors.black, // make it black to match your theme
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        // ✅ Keeps content inside safe area (no notch overlap)
        child: SingleChildScrollView(
          // ✅ Whole screen becomes scrollable (fixes overflow)
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(currentStep: 3),
              const SizedBox(height: 30),
              const Text(
                "Create Password",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ✅ Password Input
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(
                  () {},
                ), // ✅ Rebuild UI when typing (updates strength)
              ),

              // ✅ Password Strength Indicator
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: passwordStrength,
                backgroundColor: Colors.grey[300],
                color: strengthColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 5),
              Text(
                "Strength: $strengthText",
                style: TextStyle(
                  color: strengthColor,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ✅ Requirements List (using helper)
              _buildRequirement(
                "Must have a minimum of 8 characters",
                hasMinLength,
              ),
              _buildRequirement(
                "Must include at least 1 uppercase character",
                hasUpper,
              ),
              _buildRequirement(
                "Must include at least 1 lowercase character",
                hasLower,
              ),
              _buildRequirement("Must include at least 1 number", hasNumber),
              _buildRequirement(
                "Must include at least one special character (!@#...)",
                hasSpecial,
              ),
              const SizedBox(height: 20),

              // ✅ Confirm Password Input
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Continue Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuccessScreen()),
                  );
                },
                child: const Text("Continue", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Fixed Requirement Row (prevents RIGHT overflow issue)
  Widget _buildRequirement(String text, bool condition) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // align icon top
        children: [
          Icon(
            condition ? Icons.check_circle : Icons.radio_button_unchecked,
            color: condition ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),

          // ✅ Expanded lets text wrap to next line instead of overflowing
          Expanded(
            child: Text(
              text,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Step Progress Indicator ----------------
class StepProgress extends StatelessWidget {
  final int currentStep; // 1-based index
  final int totalSteps;
  const StepProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // ✅ center everything
      children: List.generate(totalSteps, (index) {
        int stepIndex = index + 1;
        bool isCompleted = stepIndex < currentStep;
        bool isCurrent = stepIndex == currentStep;

        return Row(
          children: [
            // Step Circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.white,
                border: Border.all(
                  color: (isCompleted || isCurrent)
                      ? Colors.green
                      : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 26, color: Colors.white)
                    : isCurrent
                    ? Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      )
                    : null,
              ),
            ),

            // Connector line (only between steps)
            if (stepIndex < totalSteps)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Container(
                  width: 40, // fixed line width instead of Expanded
                  height: 4,
                  color: stepIndex < currentStep
                      ? Colors.green
                      : Colors.grey[300],
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ---------------- STEP 4: Success Screen ----------------
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black), // back arrow
        title: const Text(
          "Success", // ✅ Your text here
          style: TextStyle(
            color: Colors.black, // make it black to match your theme
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ Use currentStep = 4 (since totalSteps = 3) → all become checked
            const StepProgress(currentStep: 4, totalSteps: 3),
            const SizedBox(height: 30),

            const SizedBox(height: 40),

            const SizedBox(height: 30),

            const Text(
              "Account Creation Successful!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Lorem Ipsum Dolor.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // Go to Login or Home
              },
              child: const Text("Login", style: TextStyle(fontSize: 16)),
            ),

            const Text(
              "By using the app, you agree to the Terms and Privacy Policy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
