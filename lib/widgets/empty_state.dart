import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'dart:async';

enum EmptyStateType {
  noChallengeHome,
  noChallengeFood,
  noChallengeWorkout,
}

class EmptyState extends StatefulWidget {
  final EmptyStateType type;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.type,
    this.onAction,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  // For carousel (home page)
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  List<EmptyStateSlide> _slides = [];

  // For explore grid (food and workout pages)
  List<ExploreCard> _exploreCards = [];

  @override
  void initState() {
    super.initState();
    if (widget.type == EmptyStateType.noChallengeHome) {
      _pageController = PageController();
      _initializeSlides();
      _startAutoScroll();
    } else {
      _initializeCards();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _initializeSlides() {
    // Only for home page - Focus on milestone journeys, pictures, trackers, and daily logs
    _slides = [
      EmptyStateSlide(
        imageUrl: "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800&q=80",
        title: "Track Your Journey",
        description: "Capture milestone photos and watch your transformation unfold",
        icon: Icons.photo_camera_rounded,
      ),
      EmptyStateSlide(
        imageUrl: "https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?w=800&q=80",
        title: "Daily Progress Logs",
        description: "Log your workouts, meals, and habits every single day",
        icon: Icons.calendar_today_rounded,
      ),
      EmptyStateSlide(
        imageUrl: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=800&q=80",
        title: "Smart Trackers",
        description: "Monitor calories, workouts, water, and weight in one place",
        icon: Icons.trending_up_rounded,
      ),
      EmptyStateSlide(
        imageUrl: "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80",
        title: "Milestone Memories",
        description: "Create stunning video journeys from your progress photos",
        icon: Icons.video_library_rounded,
      ),
    ];
  }

  void _initializeCards() {
    switch (widget.type) {
      case EmptyStateType.noChallengeFood:
        _exploreCards = [
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=800&q=80",
            title: "Meal Prep Ideas",
            subtitle: "Healthy & Quick",
            category: "Recipes",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=800&q=80",
            title: "Macro Tracking",
            subtitle: "Balance Your Diet",
            category: "Nutrition",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80",
            title: "Calorie Counter",
            subtitle: "Track Your Intake",
            category: "Tools",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1547592180-85f173990554?w=800&q=80",
            title: "Healthy Snacks",
            subtitle: "Guilt-Free Options",
            category: "Ideas",
          ),
        ];
        break;

      case EmptyStateType.noChallengeWorkout:
        _exploreCards = [
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=800&q=80",
            title: "Gym Essentials",
            subtitle: "Basic Exercises",
            category: "Strength",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800&q=80",
            title: "Cardio Blast",
            subtitle: "Burn Calories Fast",
            category: "Cardio",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=800&q=80",
            title: "Home Workouts",
            subtitle: "No Equipment",
            category: "Bodyweight",
          ),
          ExploreCard(
            imageUrl: "https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=800&q=80",
            title: "Stretching",
            subtitle: "Recovery & Flexibility",
            category: "Mobility",
          ),
        ];
        break;

      case EmptyStateType.noChallengeHome:
      // This case won't be used since home uses carousel
        break;
    }
  }

  @override
  void dispose() {
    if (widget.type == EmptyStateType.noChallengeHome) {
      _autoScrollTimer?.cancel();
      _pageController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == EmptyStateType.noChallengeHome) {
      return _buildCarouselView(context);
    } else {
      return _buildExploreView(context);
    }
  }

  // CAROUSEL VIEW (Home Page)
  Widget _buildCarouselView(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        SizedBox(height: topPadding + 16),

        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            children: [
              const Text(
                "Start Your Fitness Journey",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Create a challenge to unlock milestone tracking, daily logs, and progress photos",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),

              ),
            ],
          ),
        ),

        // Main carousel
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSlideCard(_slides[index]),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (index) {
            bool isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 24 : 8,
              decoration: BoxDecoration(
                color: isActive ? AppColors.secondary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        // Action button
        if (widget.onAction != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: widget.onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Create Challenge",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSlideCard(EmptyStateSlide slide) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.network(
                slide.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        color: AppColors.secondary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.image_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
            ),

            // Dark overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Content at bottom left
            Positioned(
              left: 24,
              bottom: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      slide.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    slide.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    slide.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
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

  // EXPLORE GRID VIEW (Food & Workout Pages)
  Widget _buildExploreView(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        SizedBox(height: topPadding + 16),

        // Header section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Start Your Fitness Journey",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Get started with a challenge to unlock personalized tracking",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),


        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Popular Routines",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _exploreCards.length,
                  itemBuilder: (context, index) {
                    return _buildExploreCard(_exploreCards[index]);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // CTA Button
        if (widget.onAction != null)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Create Challenge to Get Started",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExploreCard(ExploreCard card) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.network(
                card.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.fitness_center,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Category badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  card.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// Data models
class EmptyStateSlide {
  final String imageUrl;
  final String title;
  final String description;
  final IconData icon;

  EmptyStateSlide({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class ExploreCard {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String category;

  ExploreCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.category,
  });
}