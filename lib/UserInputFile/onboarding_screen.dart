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
import 'goal_page.dart';
import 'activity_level.dart';
import 'privacy_consent.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int currentIndex = 0;
  bool _isAnimating = false; // Prevent rapid clicks
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  final List<Widget> slides = const [
    PrivacyConsentPage(),
    GenderSelection(),
    Birthdate(),
    WeightSelectorPage(),
    HeightSelectorPage(),
    ActivityLevelPage(),
    GoalPage(),
    Profile(),
  ];

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String getButtonText() {
    if (currentIndex == 0) return "NEXT";
    if (currentIndex == slides.length - 1) return "CONFIRM";
    return "CONTINUE";
  }

  // Smooth navigation with debouncing for next page
  Future<void> _navigateNext() async {
    if (_isAnimating) return; // Prevent rapid clicks

    setState(() {
      _isAnimating = true;
    });

    // Button press animation
    _buttonAnimationController.forward();

    try {
      if (currentIndex == slides.length - 1) {
        // Navigate to main page with smooth transition
        await Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              );
            },
          ),
        );
      } else {
        // Move to next page with smooth animation
        await _controller.nextPage(
          duration: const Duration(milliseconds: 350), // Faster, smoother
          curve: Curves.easeInOutCubic, // Better curve
        );
      }
    } finally {
      // Reset animation state
      if (mounted) {
        _buttonAnimationController.reverse();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
          }
        });
      }
    }
  }

  // Smooth navigation for back button
  Future<void> _navigateBack() async {
    if (_isAnimating || currentIndex <= 0) return;

    setState(() {
      _isAnimating = true;
    });

    try {
      await _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
          }
        });
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // ⬅️ NEW Back Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (currentIndex > 0) // hide on first page
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28),
                      color: AppColors.secondary,
                      onPressed: _isAnimating ? null : _navigateBack,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // 📄 PageView with slides
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(), // Disables swipe
                  onPageChanged: (index) {
                    if (mounted) {
                      setState(() => currentIndex = index);
                    }
                  },
                  children: slides,
                ),
              ),

              const SizedBox(height: 20),

              // 🔘 Page Indicator with smooth transitions
              SmoothPageIndicator(
                controller: _controller,
                count: slides.length,
                effect: WormEffect(
                  activeDotColor: AppColors.secondary,
                  dotColor: AppColors.secondary.withOpacity(0.3),
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 8,
                ),
              ),
              const SizedBox(height: 30),

              // 🚀 Main Button with enhanced animations
              AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAnimating
                              ? AppColors.secondary.withOpacity(0.8)
                              : AppColors.secondary,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isAnimating ? 2 : 4,
                          shadowColor: AppColors.secondary.withOpacity(0.3),
                        ),
                        onPressed: _isAnimating ? null : _navigateNext,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isAnimating
                              ? SizedBox(
                            key: const ValueKey('loading'),
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textWhite.withOpacity(0.9),
                              ),
                            ),
                          )
                              : Text(
                            key: ValueKey(getButtonText()),
                            getButtonText(),
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}