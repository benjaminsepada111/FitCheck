import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'height.dart';

class WeightSelectorPage extends StatefulWidget {
  const WeightSelectorPage({Key? key}) : super(key: key);

  @override
  State<WeightSelectorPage> createState() => _WeightSelectorPageState();
}

class _WeightSelectorPageState extends State<WeightSelectorPage>
    with TickerProviderStateMixin {
  int selectedWeight = 75;
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));
    _loadSavedWeight();
  }

  Future<void> _loadSavedWeight() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.weight != null && mounted) {
      setState(() {
        selectedWeight = userData!.weight!;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onWeightChanged(int newWeight) {
    if (selectedWeight != newWeight) {
      setState(() {
        selectedWeight = newWeight;
      });

      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_isLoading) return;

    // Validate weight (must be between 20-300 kg)
    if (selectedWeight < 20 || selectedWeight > 300) {
      _showErrorSnackBar('Please select a valid weight between 20-300 kg.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await UserDataService.updateUserData(weight: selectedWeight);

      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HeightPage()),
        );
      } else if (mounted) {
        _showErrorSnackBar('Failed to save weight. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ).createShader(bounds),
              child: const Text(
                "Weight",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter your current weight in KG",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.secondary.shade600,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Selected weight with minimal animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        selectedWeight.toString(),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        "kg",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Number slider + ruler
            Expanded(
              child: WeightRuler(
                selectedWeight: selectedWeight,
                onWeightChanged: _onWeightChanged,
              ),
            ),

            // Continue Button
            Container(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'CONTINUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeightRuler extends StatefulWidget {
  final int selectedWeight;
  final ValueChanged<int> onWeightChanged;

  const WeightRuler({
    super.key,
    required this.selectedWeight,
    required this.onWeightChanged,
  });

  @override
  State<WeightRuler> createState() => _WeightRulerState();
}

class _WeightRulerState extends State<WeightRuler> {
  late PageController _pageController;
  late ScrollController _rulerController;
  bool _isUpdating = false;

  final int minWeight = 20;
  final int maxWeight = 300;
  final double rulerItemWidth = 8.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.selectedWeight - minWeight,
      viewportFraction: 0.25,
    );

    double initialRulerOffset = (widget.selectedWeight - minWeight) * rulerItemWidth * 10;
    _rulerController = ScrollController(initialScrollOffset: initialRulerOffset);
    _rulerController.addListener(_onRulerScroll);
  }

  void _onRulerScroll() {
    if (_isUpdating || !mounted) return;

    double offset = _rulerController.offset;
    int weightIndex = (offset / (rulerItemWidth * 10)).round();
    int newWeight = (minWeight + weightIndex).clamp(minWeight, maxWeight);

    if (newWeight != widget.selectedWeight) {
      _isUpdating = true;
      _pageController.animateToPage(
        newWeight - minWeight,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );

      widget.onWeightChanged(newWeight);
      HapticFeedback.lightImpact();

      // Immediate reset - no delay
      _isUpdating = false;
    }
  }

  void _onPageChanged(int index) {
    if (_isUpdating || !mounted) return;

    int newWeight = minWeight + index;
    widget.onWeightChanged(newWeight);
    HapticFeedback.lightImpact();

    // Sync ruler position immediately
    _isUpdating = true;
    double targetOffset = index * rulerItemWidth * 10;
    _rulerController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
    );

    // Immediate reset - no delay
    _isUpdating = false;
  }

  @override
  void didUpdateWidget(WeightRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeight != widget.selectedWeight && !_isUpdating) {
      int targetPage = widget.selectedWeight - minWeight;
      if (targetPage >= 0 && targetPage <= (maxWeight - minWeight)) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );

        double targetOffset = targetPage * rulerItemWidth * 10;
        _rulerController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Number slider with ultra-smooth physics
        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: _pageController,
            itemCount: maxWeight - minWeight + 1,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              int weight = minWeight + index;
              bool isSelected = weight == widget.selectedWeight;

              return Center(
                child: Text(
                  weight.toString(),
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 24,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.secondary
                        : AppColors.secondary.withOpacity(0.4),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Center indicator arrow
        SvgPicture.asset(
          "assets/icons/weight_arrow.svg",
          height: 20,
          color: AppColors.secondary[800],
        ),

        const SizedBox(height: 10),

        // Ultra-responsive ruler
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.05),
            border: Border(
              top: BorderSide(
                color: AppColors.secondary.withOpacity(0.3),
                width: 2,
              ),
              bottom: BorderSide(
                color: AppColors.secondary.withOpacity(0.3),
                width: 2,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ListView.builder(
              controller: _rulerController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: (maxWeight - minWeight + 1) * 10,
              itemBuilder: (context, index) {
                bool isMajorTick = index % 10 == 0;
                bool isHalfTick = index % 5 == 0;

                double currentWeight = minWeight + (index / 10);
                bool isSelectedArea = (currentWeight - widget.selectedWeight).abs() <= 0.5;
                bool isExactMatch = (currentWeight - widget.selectedWeight).abs() < 0.1;

                return Container(
                  width: rulerItemWidth,
                  alignment: Alignment.center,
                  child: Container(
                    width: isMajorTick ? (isExactMatch ? 3 : 2) : 2,
                    height: isMajorTick
                        ? (isExactMatch ? 45 : 40)
                        : isHalfTick
                        ? (isSelectedArea ? 28 : 25)
                        : (isSelectedArea ? 18 : 15),
                    decoration: BoxDecoration(
                      color: isExactMatch
                          ? AppColors.secondary
                          : isSelectedArea
                          ? AppColors.secondary.withOpacity(0.8)
                          : AppColors.secondary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: isExactMatch
                          ? [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rulerController.removeListener(_onRulerScroll);
    _rulerController.dispose();
    super.dispose();
  }
}