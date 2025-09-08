import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'signin_success.dart';
import 'package:capstone_project/color/colors.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String code = "";
  int resendSeconds = 114; // countdown for resend

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF06111D),
      body: Stack(
        children: [
          // Background SVG
          Positioned(
            top: 0,
            left: -10,
            right: 175,
            child: SizedBox(
              height: 359,
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
                  "Verification",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  "We have sent a code to your email\nexample@gmail.com",
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
              height: 230,
              child: SvgPicture.asset("assets/login_svg/bg2.svg"),
            ),
          ),

          // Verification Content
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Code input label
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "CODE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pin code fields
                  PinCodeTextField(
                    length: 5,
                    appContext: context,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    onChanged: (value) {
                      setState(() => code = value);
                    },
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 55,
                      fieldWidth: 50,
                      activeFillColor: Colors.grey[200],
                      selectedFillColor: Colors.grey[200],
                      inactiveFillColor: Colors.grey[200],
                      activeColor: Colors.transparent,
                      selectedColor: AppColors.secondary,
                      inactiveColor: Colors.transparent,
                    ),
                    enableActiveFill: true,
                  ),

                  const SizedBox(height: 24),

                  // Verify Button
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
                        if (code.length == 5) {
                          // Example: Only navigate if code is 5 digits
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SigninSuccessScreen()),
                          );
                        } else {
                          debugPrint("Please enter full 5-digit code");
                        }
                      },

                      child: const Text(
                        "VERIFY",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend timer
                  Text(
                    "Didn’t get the code? Resend in ${resendSeconds}s",
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 250),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
