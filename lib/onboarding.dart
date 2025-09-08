import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:capstone_project/LoginPages/login_page.dart';
import 'package:capstone_project/color/colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const OnboardingScreen(), // start with onboarding
      routes: {
        '/login': (context) => const LoginPage(), // 👈 register login route
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "📷",
      "title": "Welcome",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "🔥",
      "title": "Fast",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "⚡",
      "title": "Powerful",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "✅",
      "title": "Get Started",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() => isLastPage = index == onboardingData.length - 1);
                },
                itemBuilder: (context, index) {
                  final data = onboardingData[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data["image"]!,
                        style: const TextStyle(fontSize: 100),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        data["title"]!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data["description"]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SmoothPageIndicator(
              controller: _controller,
              count: onboardingData.length,
              effect: WormEffect(
                activeDotColor: AppColors.secondary,
                dotColor: AppColors.secondary.withOpacity(0.4),
                dotHeight: 10,
                dotWidth: 10,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (isLastPage) {
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  _controller.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Text(
                isLastPage ? "GET STARTED" : "NEXT",
                style: const TextStyle(
                  color: AppColors.textWhite, // 👈 change button text color
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text(
                "Skip",
                style: TextStyle(
                  color: AppColors.secondary, // 👈 your custom color
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
