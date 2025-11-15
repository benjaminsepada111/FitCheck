import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'onboarding_navigation.dart';
// Global constants for height range
const int kMinHeight = 100;
const int kMaxHeight = 320;

class HeightPage extends StatefulWidget {
  const HeightPage({super.key});

  @override
  State<HeightPage> createState() => _HeightPageState();
}

class _HeightPageState extends State<HeightPage>
    with TickerProviderStateMixin {
  int selectedHeight = 165;
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
    _loadSavedHeight();
  }

  Future<void> _loadSavedHeight() async {
    final userData = await UserDataService.loadUserData();
    if (userData?.height != null && mounted) {
      setState(() {
        selectedHeight = userData!.height!;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onHeightChanged(int newHeight) {
    if (selectedHeight != newHeight) {
      setState(() {
        selectedHeight = newHeight;
      });

      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (_isLoading) return;

    // Validate height (must be between 100-320 cm)
    if (selectedHeight < 100 || selectedHeight > 320) {
      _showErrorSnackBar('Please select a valid height between 100-320 cm.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Store data temporarily in OnboardingData instead of saving to Firebase
      final nav = OnboardingNavigation.of(context);
      if (nav != null) {
        nav.data.height = selectedHeight;

        // Move to next page (summary page)
        if (nav.onNext != null) {
          nav.onNext!();
        }
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.primary, AppColors.primary],
              ).createShader(bounds),
              child: const Text(
                "Height",
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
              "Enter your height in CM",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Selected height with minimal animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        selectedHeight.toString(),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        "cm",
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

            // Number slider + vertical ruler with synchronized scrolling
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  const SizedBox(width: 16),

                  // Number slider
                  Expanded(
                    flex: 3,
                    child: HeightNumberSlider(
                      selectedHeight: selectedHeight,
                      onHeightChanged: _onHeightChanged,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Arrow indicator
                  Transform.rotate(
                    angle: -90 * 3.1415926535 / 180,
                    child: SvgPicture.asset(
                      "assets/icons/weight_arrow.svg",
                      width: 20,
                      color: AppColors.secondary[700],
                    ),
                  ),

                  const SizedBox(width: 2),

                  // Vertical ruler
                  HeightRuler(
                    selectedHeight: selectedHeight,
                    onHeightChanged: _onHeightChanged,
                  ),

                  const SizedBox(width: 50),
                ],
              ),
            ),

            const Spacer(),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Back Button
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        final nav = OnboardingNavigation.of(context);
                        if (nav?.onBack != null) {
                          nav!.onBack!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next Button
                  Expanded(
                    child: SizedBox(
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
                                'NEXT',
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
          ],
        ),
      ),
    );
  }
}

// -------------------- Height Number Slider --------------------
class HeightNumberSlider extends StatefulWidget {
  final int selectedHeight;
  final ValueChanged<int> onHeightChanged;

  const HeightNumberSlider({
    super.key,
    required this.selectedHeight,
    required this.onHeightChanged,
  });

  @override
  State<HeightNumberSlider> createState() => _HeightNumberSliderState();
}

class _HeightNumberSliderState extends State<HeightNumberSlider> {
  late FixedExtentScrollController _scrollController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: widget.selectedHeight - kMinHeight,
    );
  }

  @override
  void didUpdateWidget(HeightNumberSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHeight != widget.selectedHeight && !_isUpdating) {
      int targetIndex = widget.selectedHeight - kMinHeight;
      if (targetIndex >= 0 && targetIndex <= (kMaxHeight - kMinHeight)) {
        _scrollController.animateToItem(
          targetIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onSelectedItemChanged(int index) {
    if (!mounted) return;

    _isUpdating = true;
    int newHeight = kMinHeight + index;
    widget.onHeightChanged(newHeight);
    HapticFeedback.lightImpact();

    // Immediate reset - no delay
    _isUpdating = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _scrollController,
      itemExtent: 50,
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      perspective: 0.003,
      diameterRatio: 2.0,
      squeeze: 1.1,
      onSelectedItemChanged: _onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: kMaxHeight - kMinHeight + 1,
        builder: (context, index) {
          int height = kMinHeight + index;
          bool isSelected = height == widget.selectedHeight;

          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  height.toString(),
                  style: TextStyle(
                    fontSize: isSelected ? 36 : 22,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.secondary
                        : AppColors.secondary.withOpacity(0.4),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Text(
                    "cm",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// -------------------- Height Ruler --------------------
class HeightRuler extends StatefulWidget {
  final int selectedHeight;
  final ValueChanged<int> onHeightChanged;

  const HeightRuler({
    super.key,
    required this.selectedHeight,
    required this.onHeightChanged,
  });

  @override
  State<HeightRuler> createState() => _HeightRulerState();
}

class _HeightRulerState extends State<HeightRuler> {
  late ScrollController _rulerController;
  bool _isUpdating = false;
  final double rulerItemHeight = 12.0;

  @override
  void initState() {
    super.initState();
    double initialOffset =
        (widget.selectedHeight - kMinHeight) * rulerItemHeight;
    _rulerController = ScrollController(initialScrollOffset: initialOffset);
    _rulerController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isUpdating || !mounted) return;

    int index = (_rulerController.offset / rulerItemHeight).round();
    int newHeight = (kMinHeight + index).clamp(kMinHeight, kMaxHeight);

    if (newHeight != widget.selectedHeight) {
      _isUpdating = true;
      widget.onHeightChanged(newHeight);
      HapticFeedback.lightImpact();

      // Immediate reset - no delay
      _isUpdating = false;
    }
  }

  @override
  void didUpdateWidget(covariant HeightRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHeight != widget.selectedHeight && !_isUpdating) {
      double targetOffset =
          (widget.selectedHeight - kMinHeight) * rulerItemHeight;
      _rulerController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.05),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ListView.builder(
          controller: _rulerController,
          physics: const BouncingScrollPhysics(),
          itemCount: kMaxHeight - kMinHeight + 1,
          itemBuilder: (context, index) {
            int currentHeight = kMinHeight + index;
            bool isMajor = index % 10 == 0;
            bool isHalf = index % 5 == 0;
            bool isSelected = currentHeight == widget.selectedHeight;

            double lineWidth = isMajor ? 40 : isHalf ? 28 : 16;

            return Container(
              height: rulerItemHeight,
              alignment: Alignment.center,
              child: Container(
                height: isSelected ? 3 : 2,
                width: isSelected ? lineWidth + 5 : lineWidth,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.secondary.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: isSelected
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
    );
  }

  @override
  void dispose() {
    _rulerController.removeListener(_onScroll);
    _rulerController.dispose();
    super.dispose();
  }
}