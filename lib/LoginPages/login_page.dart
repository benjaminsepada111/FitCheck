import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../UserInputFile/onboarding_screen.dart';
import 'forgot_password.dart';
import 'package:capstone_project/SignUpPages/signuppage.dart';
import '../app_text_styles.dart';
import '../color/colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111D),

    body: Stack(
        children: [
          // Background SVG (put your green lines here)
          Positioned(
            top: 0,
            left: -10,
            right: 175,
            child: SizedBox(
              height: 359,
              child: SvgPicture.asset(
                "assets/login_svg/bg.svg",

              ),
            ),
          ),
          // Replace your two Text widgets with these:
          Positioned(
            top: 160, // adjust distance from top
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  "Log In",
                  style:  TextStyle(
                    fontSize: 38,
                    fontFamily: "Sen",
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  "Sign in to your existing account!",
                  style: TextStyle(
                    fontFamily: "Sen",
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
              height: 230,
              child: SvgPicture.asset(
                "assets/login_svg/bg2.svg",

              ),
            ),
          ),

          // Login Content
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Center(
                      child: Column(
                        children: [

                          SizedBox(height: 8),

                        ],
                      ),
                    ),


                    // Email field
                    const Text(
                      "EMAIL",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: "Enter Username or Email",
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    const Text(
                      "PASSWORD",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: "Enter Password",
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Remember + Forgot
                    Row(
                      children: [
                        Checkbox(value: false, onChanged: (v) {}),
                        const Text("Remember me"),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password",
                            style: TextStyle( color: AppColors.secondary,),
                          ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 12),

                    // Login Button
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
                            MaterialPageRoute(
                                builder: (context) => const OnboardingScreen()),
                          );
                        },
                        child: const Text(
                          "LOG IN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don’t have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPage()), // 👈 navigate to signup.dart
                            );
                          },
                          child: const Text(
                            "SIGN UP",
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),


                    const SizedBox(height: 26),

                    // OR divider
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 1,
                            color: Colors.grey,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text("Or"),
                        ),
                        Expanded(
                          child: Divider(
                            thickness: 1,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // Social Buttons

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Google Button
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              'assets/login_svg/google.svg',
                              height: 24,
                              width: 24,
                            ),
                          ),
                        ),

                        // Facebook Button
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[800],
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              'assets/login_svg/facebook.svg',
                              height: 24,
                              width: 24,
                              color: Colors.white, // optional if you want white logo
                            ),
                          ),
                        ),

                        // Apple Button
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              'assets/login_svg/apple.svg',
                              height: 24,
                              width: 24,
                              color: Colors.white, // ensures logo shows on black
                            ),
                          ),
                        ),
                      ],

                    )




                  ],

                ),

              ),

            ),
          ),
        ],
      ),

    );

  }
}
