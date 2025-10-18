import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_project/FoodPage/foodlogger.dart';
import 'package:capstone_project/FoodPage/mealsection.dart';
import 'package:capstone_project/FoodPage/recommendedfoods.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/MainPage/create_challenge_sheet.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:image_picker/image_picker.dart';

class FoodPage extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(Challenge)? onChallengeCreated;
  final VoidCallback? onCaloriesUpdated;

  const FoodPage({
    super.key,
    this.currentChallenge,
    this.onChallengeCreated,
    this.onCaloriesUpdated,
  });

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> with TickerProviderStateMixin {
  bool get hasChallenge => widget.currentChallenge != null;

  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Keys to access child widget states
  final GlobalKey<MealsSectionState> _mealsSectionKey = GlobalKey<MealsSectionState>();
  final GlobalKey<FoodLoggerState> _foodLoggerKey = GlobalKey<FoodLoggerState>();

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _slideController.forward();
        _fadeController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _bounceController.repeat(reverse: true);
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onChallengeCreated(Challenge challenge) {
    if (widget.onChallengeCreated != null) {
      widget.onChallengeCreated!(challenge);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Challenge "${challenge.title}" created!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _addRecommendedFoodToMeal(String foodName, int calories) {
    final hour = DateTime.now().hour;
    String mealType;

    if (hour >= 6 && hour < 11) {
      mealType = 'Breakfast';
    } else if (hour >= 11 && hour < 15) {
      mealType = 'Lunch';
    } else if (hour >= 15 && hour < 18) {
      mealType = 'Snack';
    } else {
      mealType = 'Dinner';
    }

    // Show dialog to enter grams and optional image for recommended food
    _showAddRecommendedFoodDialog(foodName, calories, mealType);
  }

  void _showAddRecommendedFoodDialog(String foodName, int caloriesPer100g, String mealType) {
    final TextEditingController gramsController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    File? selectedImage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickImage(ImageSource source) async {
            try {
              final pickedFile = await picker.pickImage(
                source: source,
                imageQuality: 80,
                maxWidth: 1200,
              );

              if (pickedFile != null) {
                setModalState(() {
                  selectedImage = File(pickedFile.path);
                });
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to pick image'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          }

          void removeImage() {
            setModalState(() {
              selectedImage = null;
            });
          }

          Future<void> saveFood() async {
            // Prevent multiple submissions
            if (isLoading) return;

            final gramsText = gramsController.text.trim();
            if (gramsText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter the amount in grams'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }

            final grams = double.tryParse(gramsText);
            if (grams == null || grams <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter a valid amount greater than 0'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }

            if (grams > 5000) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Amount seems too large. Please enter a reasonable amount.'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }

            // Set loading state
            setModalState(() {
              isLoading = true;
            });

            try {
              // Calculate actual calories based on grams
              final actualCalories = ((caloriesPer100g / 100) * grams).round();

              // Upload image if selected
              String? uploadedImageUrl;
              if (selectedImage != null && widget.currentChallenge != null) {
                uploadedImageUrl = await ImageStorageService.uploadFoodImage(
                  selectedImage!,
                  challengeId: widget.currentChallenge!.id,
                );

                if (uploadedImageUrl == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Failed to upload image. Food will be saved without photo.'),
                        backgroundColor: Colors.orange.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
                _confirmAddFood(foodName, actualCalories, mealType, grams: grams, imageUrl: uploadedImageUrl);
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to add food. Please try again.'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.restaurant_menu,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foodName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Add to $mealType',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF666666), size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Calories info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.1),
                          AppColors.secondary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_fire_department,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$caloriesPer100g cal per 100g',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grams input
                  Text(
                    'Enter Amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: gramsController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: "Enter amount in grams",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      suffixText: 'grams',
                      suffixStyle: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.secondary, width: 2),
                      ),
                    ),
                  ),

                  // Calorie preview
                  if (gramsController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final grams = double.tryParse(gramsController.text);
                        if (grams == null || grams <= 0) return const SizedBox.shrink();

                        final totalCalories = ((caloriesPer100g / 100) * grams).round();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.1),
                                AppColors.secondary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.secondary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Calories',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalCalories cal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${grams.toStringAsFixed(0)}g',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Image upload section
                  Text(
                    'Food Photo (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (selectedImage == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 20),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 20),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            selectedImage!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                      ],
                    ),
                  ),
                ),
                // Action buttons - outside scroll view
                Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    top: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : saveFood,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.6),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Add Food',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('chicken') || name.contains('meat')) return Icons.set_meal;
    if (name.contains('fish') || name.contains('salmon')) return Icons.set_meal;
    if (name.contains('apple') || name.contains('banana') || name.contains('fruit')) return Icons.apple;
    if (name.contains('rice') || name.contains('grain')) return Icons.grain;
    if (name.contains('egg')) return Icons.egg_alt;
    if (name.contains('milk') || name.contains('yogurt')) return Icons.local_drink;
    if (name.contains('vegetable') || name.contains('broccoli')) return Icons.grass;
    return Icons.restaurant_menu;
  }

  void _confirmAddFood(String foodName, int calories, String mealType, {double? grams, String? imageUrl}) async {
    if (!mounted) return;

    try {
      final foodEntry = FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fdcId: 0,
        foodName: foodName,
        servingSize: grams ?? 100.0,
        servingUnit: 'g',
        caloriesPer100g: grams != null && grams > 0
            ? (calories / grams) * 100
            : calories.toDouble(),
        imageUrl: imageUrl,
      );

      if (widget.currentChallenge == null) {
        throw Exception('No active challenge');
      }

      final success = await FoodLogService.addFoodEntry(
        DateTime.now(),
        mealType,
        foodEntry,
        challengeId: widget.currentChallenge!.id,
      );

      if (success && mounted) {
        // Refresh both the meal section and food logger to show updates
        await _mealsSectionKey.currentState?.loadMealData();

        await _foodLoggerKey.currentState?.refreshData();

        if (widget.onCaloriesUpdated != null) {
          widget.onCaloriesUpdated!();
        }

        // Show success feedback after refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Text('Successfully added!'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add $foodName. Please try again.'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding $foodName. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasChallenge) {
      return _buildNoChallengeUI();
    }
    return _buildMainFoodPage();
  }

  Widget _buildNoChallengeUI() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary.withOpacity(0.08),
              Colors.white,
              AppColors.secondary.withOpacity(0.03),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),

                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.secondary.withOpacity(0.2),
                                AppColors.secondary.withOpacity(0.1),
                                AppColors.secondary.withOpacity(0.05),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary.withOpacity(0.2),
                                      AppColors.secondary.withOpacity(0.15),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 60,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Start Your\nNutrition Journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Create a challenge to unlock food logging, personalized recommendations, and meal tracking!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _navigateToCreateChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Create Your First Challenge',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: TextButton.icon(
                    onPressed: _showChallengeExamples,
                    icon: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                    label: Text(
                      'View challenge ideas',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainFoodPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodLogger(
            key: _foodLoggerKey,
            currentChallenge: widget.currentChallenge,
            onCaloriesUpdated: widget.onCaloriesUpdated,
          ),
          const SizedBox(height: 20),
          RecommendedFoods(
            onFoodTapped: (foodName, calories) {
              _addRecommendedFoodToMeal(foodName, calories);
            },
          ),
          const SizedBox(height: 20),
          MealsSection(
            key: _mealsSectionKey,
            onCaloriesUpdated: () async {
              // Refresh Food Logger when food is added from Meals section
              await _foodLoggerKey.currentState?.refreshData();
              // Also update home page trackers
              widget.onCaloriesUpdated?.call();
            },
            challengeId: widget.currentChallenge?.id,
          ),
        ],
      ),
    );
  }

  void _navigateToCreateChallenge() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateChallengeSheet(
        onChallengeCreated: _onChallengeCreated,
      ),
    );
  }

  void _showChallengeExamples() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Challenge Ideas',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildChallengeExample(
              Icons.water_drop_rounded,
              'Stay Hydrated',
              'Drink 8 glasses of water daily',
              AppColors.secondary.shade600,
            ),
            _buildChallengeExample(
              Icons.eco_rounded,
              '5-A-Day Challenge',
              'Eat 5 portions of fruits & vegetables',
              AppColors.secondary.shade600,
            ),
            _buildChallengeExample(
              Icons.fitness_center_rounded,
              'Protein Power',
              'Meet your daily protein goals',
              AppColors.secondary.shade600,
            ),
            _buildChallengeExample(
              Icons.self_improvement_rounded,
              'Mindful Eating',
              'Practice conscious eating habits',
             AppColors.secondary.shade600,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToCreateChallenge();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create My Challenge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeExample(
      IconData icon, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}