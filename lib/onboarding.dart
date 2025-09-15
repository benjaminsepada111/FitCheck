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
      home: const OnboardingScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

// Responsive utility class
class ResponsiveUtils {
  // Get responsive font size based on screen width
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    // Scale factor based on shortest side (better for orientation changes)
    double scaleFactor;
    if (shortestSide < 600) {
      // Phone
      scaleFactor = shortestSide / 375; // Base iPhone size
    } else {
      // Tablet
      scaleFactor = shortestSide / 768; // Base iPad size
    }

    return baseSize * scaleFactor.clamp(0.8, 1.8);
  }

  // Get responsive height as fraction of screen height
  static double getResponsiveHeight(BuildContext context, double fraction) {
    return MediaQuery.of(context).size.height * fraction;
  }

  // Get responsive width as fraction of screen width
  static double getResponsiveWidth(BuildContext context, double fraction) {
    return MediaQuery.of(context).size.width * fraction;
  }

  // Get responsive padding based on screen size
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

  // Check if device is tablet
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  // Get responsive image size
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

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/strawberry.png",
      "title": "Welcome",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "assets/images/banana.png",
      "title": "Fast",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "assets/images/strawberry.png",
      "title": "Powerful",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
    {
      "image": "assets/images/banana.png",
      "title": "Get Started",
      "description": "Lorem ipsum dolor sit amet consectetur. Diam sem nunc mi rhoncus velit orci."
    },
  ];

  Widget buildImage(BuildContext context, String image) {
    final imageSize = ResponsiveUtils.getResponsiveImageSize(context, 200);

    if (image.startsWith("assets/")) {
      return Image.asset(
        image,
        height: imageSize,
        width: imageSize,
        fit: BoxFit.contain,
      );
    } else {
      return Text(
        image,
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 100),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalPadding = ResponsiveUtils.getResponsivePadding(context, 20);
    final verticalPadding = ResponsiveUtils.getResponsivePadding(context, 40);

    return Scaffold(
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
          child: PageView.builder(
            controller: _controller,
            itemCount: onboardingData.length,
            onPageChanged: (index) {
              setState(() => isLastPage = index == onboardingData.length - 1);
            },
            itemBuilder: (context, index) {
              return _buildOnboardingPage(context, index);
            },
          ),
        ),
        Flexible(
          flex: 2,
          child: _buildBottomSection(context),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PageView.builder(
            controller: _controller,
            itemCount: onboardingData.length,
            onPageChanged: (index) {
              setState(() => isLastPage = index == onboardingData.length - 1);
            },
            itemBuilder: (context, index) {
              return _buildOnboardingPage(context, index, isLandscapeContent: true);
            },
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getResponsivePadding(context, 20),
            ),
            child: _buildBottomSection(context),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingPage(BuildContext context, int index, {bool isLandscapeContent = false}) {
    final data = onboardingData[index];
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(context, 22);
    final descriptionFontSize = ResponsiveUtils.getResponsiveFontSize(context, 14);
    final spacing = ResponsiveUtils.getResponsiveHeight(context, 0.03);
    final isTablet = ResponsiveUtils.isTablet(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image container with flexible sizing
                Flexible(
                  flex: isLandscapeContent ? 4 : 3,
                  child: Container(
                    alignment: Alignment.center,
                    child: buildImage(context, data["image"]!),
                  ),
                ),
                SizedBox(height: spacing),

                // Title with responsive sizing
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 600 : double.infinity,
                    ),
                    child: Text(
                      data["title"]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize.clamp(18, 32),
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing * 0.5),

                // Description with responsive sizing
                Flexible(
                  flex: 2,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 500 : double.infinity,
                    ),
                    child: Text(
                      data["description"]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: descriptionFontSize.clamp(12, 18),
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Page indicator
        Container(
          margin: EdgeInsets.only(bottom: spacing),
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

        // Main button with responsive sizing
        Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 400 : double.infinity,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              minimumSize: Size(double.infinity, buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
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
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: buttonFontSize.clamp(14, 20),
              ),
            ),
          ),
        ),

        // Skip button - only shows if NOT last page
        if (!isLastPage)
          Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 400 : double.infinity,
              minHeight: 44, // Minimum tap target size for accessibility
            ),
            margin: EdgeInsets.only(top: spacing * 0.5),
            child: TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
              child: Text(
                "Skip",
                style: TextStyle(
                  color: AppColors.secondary,
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