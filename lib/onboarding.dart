import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:capstone_project/color/colors.dart';

// Responsive utility class
class ResponsiveUtils {
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    double scaleFactor;
    if (shortestSide < 600) {
      scaleFactor = shortestSide / 375; // Phone
    } else {
      scaleFactor = shortestSide / 768; // Tablet
    }
    return baseSize * scaleFactor.clamp(0.8, 1.8);
  }

  static double getResponsiveHeight(BuildContext context, double fraction) {
    return MediaQuery.of(context).size.height * fraction;
  }

  static double getResponsiveWidth(BuildContext context, double fraction) {
    return MediaQuery.of(context).size.width * fraction;
  }

  static double getResponsivePadding(BuildContext context, double basePadding) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide < 600) {
      return basePadding;
    } else if (shortestSide < 900) {
      return basePadding * 1.5;
    } else {
      return basePadding * 2.0;
    }
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  static double getResponsiveImageSize(BuildContext context, double baseSize) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      return (screenHeight * 0.2).clamp(120, 250);
    } else {
      return (screenHeight * 0.25).clamp(150, 300);
    }
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
  bool _isAnimating = false;
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "🍓",
      "title": "Welcome to FreshMart",
      "description": "Discover fresh fruits and vegetables delivered right to your doorstep. Quality you can trust, convenience you'll love."
    },
    {
      "image": "⚡",
      "title": "Lightning Fast Delivery",
      "description": "Get your groceries delivered in under 30 minutes. Fresh produce has never been this accessible and quick."
    },
    {
      "image": "💪",
      "title": "Premium Quality",
      "description": "Hand-picked products from trusted local farmers. Every item is carefully selected for freshness and quality."
    },
    {
      "image": "🚀",
      "title": "Ready to Start?",
      "description": "Join thousands of satisfied customers who trust us for their daily grocery needs. Let's get started!"
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_isUserInteracting && mounted) {
        if (_currentPage < onboardingData.length - 1) {
          _controller.nextPage(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        } else {
          // Reset to first page when reaching the end
          _controller.animateToPage(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  void _pauseAutoSlide() {
    setState(() {
      _isUserInteracting = true;
    });
    // Resume auto-slide after 3 seconds of no interaction
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });
  }

  Widget buildImage(BuildContext context, String image) {
    final imageSize = ResponsiveUtils.getResponsiveImageSize(context, 200);
    if (image.startsWith("assets/")) {
      return Image.asset(
        image,
        height: imageSize,
        width: imageSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            "📱",
            style: TextStyle(
              fontSize: imageSize * 0.8,
            ),
          );
        },
      );
    } else {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(imageSize / 2),
        ),
        child: Center(
          child: Text(
            image,
            style: TextStyle(
              fontSize: imageSize * 0.5,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _navigateNext() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    try {
      if (isLastPage) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _pauseAutoSlide();
        await _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
          }
        });
      }
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalPadding = ResponsiveUtils.getResponsivePadding(context, 20);

    final rawVerticalPadding = ResponsiveUtils.getResponsivePadding(context, 40);
    final verticalPadding = min(rawVerticalPadding, MediaQuery.of(context).size.height * 0.06);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: isLandscape && !isTablet
              ? _buildLandscapeLayout(context)
              : _buildPortraitLayout(context),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 8,
          child: GestureDetector(
            onTap: _pauseAutoSlide,
            onPanStart: (_) => _pauseAutoSlide(),
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  isLastPage = index == onboardingData.length - 1;
                });
              },
              itemBuilder: (context, index) {
                return _buildOnboardingPage(context, index);
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildBottomSection(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _pauseAutoSlide,
            onPanStart: (_) => _pauseAutoSlide(),
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  isLastPage = index == onboardingData.length - 1;
                });
              },
              itemBuilder: (context, index) {
                return _buildOnboardingPage(context, index, isLandscapeContent: true);
              },
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: ResponsiveUtils.getResponsivePadding(context, 20),
                bottom: 2,
              ),
              child: _buildBottomSection(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingPage(BuildContext context, int index, {bool isLandscapeContent = false}) {
    final data = onboardingData[index];
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(context, 24);
    final descriptionFontSize = ResponsiveUtils.getResponsiveFontSize(context, 16);
    final spacing = ResponsiveUtils.getResponsiveHeight(context, 0.04);
    final isTablet = ResponsiveUtils.isTablet(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Auto-sliding image section
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey('image_$index'),
                      height: isLandscapeContent ? constraints.maxHeight * 0.4 : constraints.maxHeight * 0.35,
                      alignment: Alignment.center,
                      child: buildImage(context, data["image"]!),
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Auto-sliding title section
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey('title_$index'),
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 600 : double.infinity,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        data["title"]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleFontSize.clamp(20, 36),
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 0.7),

                  // Auto-sliding description section
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey('desc_$index'),
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 500 : double.infinity,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        data["description"]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: descriptionFontSize.clamp(14, 20),
                          color: Colors.grey.shade600,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final double buttonHeight = ResponsiveUtils.getResponsiveHeight(context, 0.07).clamp(50, 70);
    final spacing = ResponsiveUtils.getResponsiveHeight(context, 0.025);
    final buttonFontSize = ResponsiveUtils.getResponsiveFontSize(context, 16);
    final skipFontSize = ResponsiveUtils.getResponsiveFontSize(context, 14);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Page indicator with auto-slide progress - CENTERED
        Container(
          margin: EdgeInsets.only(bottom: spacing),
          child: Center(
            child: SmoothPageIndicator(
              controller: _controller,
              count: onboardingData.length,
              effect: WormEffect(
                activeDotColor: AppColors.secondary,
                dotColor: AppColors.secondary.withOpacity(0.4),
                dotHeight: isTablet ? 12 : 10,
                dotWidth: isTablet ? 12 : 10,
                spacing: isTablet ? 8 : 6,
              ),
            ),
          ),
        ),
        // Manual navigation buttons remain the same
        Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : double.infinity,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAnimating
                    ? AppColors.secondary.withOpacity(0.8)
                    : AppColors.secondary,
                minimumSize: Size(double.infinity, buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _isAnimating ? 1 : 2,
              ),
              onPressed: _isAnimating ? null : () {
                _pauseAutoSlide();
                _navigateNext();
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isAnimating
                    ? SizedBox(
                  key: const ValueKey('loading'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textWhite.withOpacity(0.8)
                    ),
                  ),
                )
                    : Text(
                  key: ValueKey(isLastPage ? 'get_started' : 'next'),
                  isLastPage ? "GET STARTED" : "NEXT",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: buttonFontSize.clamp(14, 20),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!isLastPage)
          Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 400 : double.infinity,
              minHeight: 44,
            ),
            margin: EdgeInsets.only(top: spacing * 0.5),
            child: TextButton(
              onPressed: _isAnimating ? null : () {
                _pauseAutoSlide();
                _skipOnboarding();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                "Skip",
                style: TextStyle(
                  color: _isAnimating
                      ? AppColors.secondary.withOpacity(0.5)
                      : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: skipFontSize.clamp(12, 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}