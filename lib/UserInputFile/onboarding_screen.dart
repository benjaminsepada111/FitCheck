import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'profile.dart';
import 'genderselection.dart';
import 'weightselectorpage.dart';
import 'birthdate.dart';
import 'height.dart';
import '../LoginPages/login_page.dart';
import '../color/colors.dart';
import 'package:capstone_project/main_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<Widget> slides = const [
    GenderSelection(),
    Slide4(),
    WeightSelectorPage(),
    Slide5(),
    Slide1(),


  ];

  String getButtonText() {
    if (currentIndex == 0) return "NEXT";
    if (currentIndex == slides.length - 1) return "CONFIRM";
    return "CONTINUE";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // 🔙 Navigation bar with Back button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentIndex > 0)
                    TextButton.icon(
                      onPressed: () {
                        if (currentIndex > 0) {
                          _controller.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      label: const Text(
                        "Back",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    )
                  else
                    const SizedBox(width: 70), // keep spacing aligned


                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Skip",
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 📄 PageView with slides
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(), // 👈 disables swipe
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  children: slides,
                ),
              ),


              const SizedBox(height: 20),

              // 🔘 Page Indicator
              SmoothPageIndicator(
                controller: _controller,
                count: slides.length,
                effect: WormEffect(
                  activeDotColor: AppColors.secondary,
                  dotColor: AppColors.primary.withOpacity(0.3),
                  dotHeight: 10,
                  dotWidth: 10,
                ),
              ),
              const SizedBox(height: 30),

              // 🚀 Main Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (currentIndex == slides.length - 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainPage()),
                    );
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  getButtonText(),
                  style: const TextStyle(color: AppColors.textWhite),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
