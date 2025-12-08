import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/main_page.dart';
import 'nickname_page.dart';
import 'hobbies_page.dart';
import 'genderselection.dart';
import 'birthdate.dart';
import 'weightselectorpage.dart';
import 'height.dart';
import 'onboarding_summary_page.dart';
import 'onboarding_navigation.dart';
import 'onboarding_data.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7; // Updated to include summary page
  final OnboardingData _data = OnboardingData();

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _currentPage / _totalPages,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _progressController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Dismiss keyboard before navigation
    FocusScope.of(context).unfocus();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    // Dismiss keyboard before navigation
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: (page + 1) / _totalPages,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _progressController.reset();
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Smooth Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Row(
                    children: List.generate(_totalPages, (index) {
                      double progress = (_progressAnimation.value * _totalPages);
                      bool isFilled = index < progress;
                      bool isPartial = index < progress && index >= progress - 1;
                      double fillAmount = isPartial ? (progress - index) : (isFilled ? 1.0 : 0.0);

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: index < _totalPages - 1 ? 8 : 0),
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fillAmount,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            // PageView with all onboarding screens
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: null,
                    data: _data,
                    child: const NicknamePage(),
                  ),
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: _previousPage,
                    data: _data,
                    child: const HobbiesPage(),
                  ),
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: _previousPage,
                    data: _data,
                    child: const GenderSelection(),
                  ),
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: _previousPage,
                    data: _data,
                    child: const BirthdatePage(),
                  ),
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: _previousPage,
                    data: _data,
                    child: const WeightSelectorPage(),
                  ),
                  OnboardingNavigation(
                    onNext: _nextPage,
                    onBack: _previousPage,
                    data: _data,
                    child: const HeightPage(),
                  ),
                  OnboardingNavigation(
                    onNext: () async {
                      // Navigate to main app after confirming
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const MainPage()),
                        (route) => false,
                      );
                    },
                    onBack: _previousPage,
                    data: _data,
                    child: OnboardingSummaryPage(
                      name: _data.name ?? '',
                      bio: _data.bio,
                      hobbies: _data.hobbies,
                      gender: _data.gender ?? '',
                      birthDate: _data.birthDate ?? DateTime.now(),
                      weight: _data.weight ?? 0.0,
                      height: _data.height ?? 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
