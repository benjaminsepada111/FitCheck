import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_project/FoodPage/calorie_tracker_header.dart';
import 'package:capstone_project/FoodPage/mealsection.dart';
import 'package:capstone_project/FoodPage/recommendedfoods.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/MainPage/create_challenge_sheet.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _FoodPageState extends State<FoodPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool get hasChallenge => widget.currentChallenge != null;

  @override
  bool get wantKeepAlive => true; // Keep this page alive

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
  final GlobalKey<MealsSectionState> _mealsSectionKey =
      GlobalKey<MealsSectionState>();
  final GlobalKey<CalorieTrackerHeaderState> _calorieTrackerKey =
      GlobalKey<CalorieTrackerHeaderState>();

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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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
      final r = context.responsive;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.size(4)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: r.size(16)),
              ),
              ResponsiveGap.horizontal(12),
              Expanded(
                child: Text(
                  'Challenge "${challenge.title}" created!',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.font(14, min: 12, max: 16)),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.size(12)),
          ),
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

  void _showAddRecommendedFoodDialog(
    String foodName,
    int caloriesPer100g,
    String mealType,
  ) {
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
              // Handle camera permission
              if (source == ImageSource.camera) {
                if (Platform.isAndroid) {
                  // On Android, explicitly request permission
                  var status = await Permission.camera.request();
                  if (!status.isGranted) {
                    if (!context.mounted) return;
                    final r = context.responsive;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Camera permission denied', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.size(12)),
                        ),
                      ),
                    );
                    return;
                  }
                } else if (Platform.isIOS) {
                  // On iOS, check permission status first
                  var status = await Permission.camera.status;
                  if (status.isDenied || status.isRestricted) {
                    // Request permission - this will show the dialog on iOS
                    status = await Permission.camera.request();
                    if (!status.isGranted) {
                      if (!context.mounted) return;
                      // If permanently denied, offer to open settings
                      if (status.isPermanentlyDenied) {
                        final shouldOpen = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Camera Permission Required'),
                            content: const Text(
                              'Camera permission is required to take photos. Please enable it in Settings.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Open Settings'),
                              ),
                            ],
                          ),
                        );
                        if (shouldOpen == true) {
                          await openAppSettings();
                        }
                      } else {
                        final r = context.responsive;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Camera permission denied', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                            ),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  // If permission is already granted or just granted, proceed
                }
              }
              // On iOS, image_picker handles photo library permissions automatically via PHPickerViewController

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
              if (context.mounted) {
                final r = context.responsive;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to pick image', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.size(12)),
                    ),
                  ),
                );
              }
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
            final r = context.responsive;
            if (gramsText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter the amount in grams', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.size(12)),
                  ),
                ),
              );
              return;
            }

            final grams = double.tryParse(gramsText);
            if (grams == null || grams <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please enter a valid amount greater than 0',
                    style: TextStyle(fontSize: r.font(14, min: 12, max: 16)),
                  ),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.size(12)),
                  ),
                ),
              );
              return;
            }

            if (grams > 5000) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Amount seems too large. Please enter a reasonable amount.',
                    style: TextStyle(fontSize: r.font(14, min: 12, max: 16)),
                  ),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.size(12)),
                  ),
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
                    final r = context.responsive;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to upload image. Food will be saved without photo.',
                          style: TextStyle(fontSize: r.font(14, min: 12, max: 16)),
                        ),
                        backgroundColor: Colors.orange.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.size(12)),
                        ),
                      ),
                    );
                  }
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
                _confirmAddFood(
                  foodName,
                  actualCalories,
                  mealType,
                  grams: grams,
                  imageUrl: uploadedImageUrl,
                );
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
              });

              if (context.mounted) {
                final r = context.responsive;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to add food. Please try again.',
                      style: TextStyle(fontSize: r.font(14, min: 12, max: 16)),
                    ),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.size(12)),
                    ),
                  ),
                );
              }
            }
          }

          final r = context.responsive;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(r.size(24))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: r.size(24),
                      right: r.size(24),
                      top: r.size(24),
                      bottom: r.size(24),
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
                                    padding: EdgeInsets.all(r.size(10)),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(r.size(12)),
                                    ),
                                    child: Icon(
                                      Icons.restaurant_menu,
                                      color: AppColors.secondary,
                                      size: r.size(24),
                                    ),
                                  ),
                                  ResponsiveGap.horizontal(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          foodName,
                                          style: TextStyle(
                                            fontSize: r.font(18, min: 16, max: 20),
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Add to $mealType',
                                          style: TextStyle(
                                            fontSize: r.font(13, min: 12, max: 14),
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
                              constraints: BoxConstraints(
                                minWidth: r.tapTarget(44),
                                minHeight: r.tapTarget(44),
                              ),
                              icon: Icon(
                                Icons.close,
                                color: const Color(0xFF666666),
                                size: r.size(24),
                              ),
                            ),
                          ],
                        ),
                        ResponsiveGap.vertical(24),

                        // Calories info
                        Container(
                          padding: EdgeInsets.all(r.size(16)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.1),
                                AppColors.secondary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(r.size(12)),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                              width: r.size(1.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(r.size(8)),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(r.size(8)),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.secondary,
                                  size: r.size(20),
                                ),
                              ),
                              ResponsiveGap.horizontal(12),
                              Text(
                                '$caloriesPer100g cal per 100g',
                                style: TextStyle(
                                  fontSize: r.font(15, min: 13, max: 17),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ResponsiveGap.vertical(24),

                        // Grams input
                        Text(
                          'Enter Amount',
                          style: TextStyle(
                            fontSize: r.font(15, min: 13, max: 17),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        ResponsiveGap.vertical(10),
                        TextField(
                          controller: gramsController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setModalState(() {}),
                          style: TextStyle(fontSize: r.font(16, min: 14, max: 18)),
                          decoration: InputDecoration(
                            hintText: "Enter amount in grams",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: r.font(16, min: 14, max: 18),
                            ),
                            suffixText: 'grams',
                            suffixStyle: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.font(14, min: 12, max: 16),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.size(16),
                              vertical: r.size(16),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                              borderSide: BorderSide(
                                color: AppColors.secondary,
                                width: r.size(2),
                              ),
                            ),
                          ),
                        ),

                        // Calorie preview
                        if (gramsController.text.isNotEmpty) ...[
                          ResponsiveGap.vertical(16),
                          Builder(
                            builder: (context) {
                              final grams = double.tryParse(
                                gramsController.text,
                              );
                              if (grams == null || grams <= 0) {
                                return const SizedBox.shrink();
                              }

                              final totalCalories =
                                  ((caloriesPer100g / 100) * grams).round();

                              return Container(
                                padding: EdgeInsets.all(r.size(16)),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary.withValues(
                                        alpha: 0.1,
                                      ),
                                      AppColors.secondary.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(r.size(12)),
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: r.size(1.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(r.size(10)),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(r.size(10)),
                                      ),
                                      child: Icon(
                                        Icons.local_fire_department,
                                        color: AppColors.secondary,
                                        size: r.size(24),
                                      ),
                                    ),
                                    ResponsiveGap.horizontal(14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Calories',
                                            style: TextStyle(
                                              fontSize: r.font(13, min: 12, max: 14),
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          ResponsiveGap.vertical(4),
                                          Text(
                                            '$totalCalories cal',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.secondary,
                                              fontSize: r.font(24, min: 20, max: 26),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: r.size(12),
                                        vertical: r.size(6),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(r.size(8)),
                                      ),
                                      child: Text(
                                        '${grams.toStringAsFixed(0)}g',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondary,
                                          fontSize: r.font(14, min: 12, max: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        ResponsiveGap.vertical(24),

                        // Image upload section
                        Text(
                          'Food Photo (Optional)',
                          style: TextStyle(
                            fontSize: r.font(15, min: 13, max: 17),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        ResponsiveGap.vertical(10),

                        if (selectedImage == null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickImage(ImageSource.camera),
                                  icon: Icon(Icons.camera_alt, size: r.size(20)),
                                  label: Text('Camera', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.secondary,
                                    side: BorderSide(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: r.size(12),
                                    ),
                                    minimumSize: Size(double.infinity, r.tapTarget(44)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(r.size(12)),
                                    ),
                                  ),
                                ),
                              ),
                              ResponsiveGap.horizontal(12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickImage(ImageSource.gallery),
                                  icon: Icon(
                                    Icons.photo_library,
                                    size: r.size(20),
                                  ),
                                  label: Text('Gallery', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.secondary,
                                    side: BorderSide(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: r.size(12),
                                    ),
                                    minimumSize: Size(double.infinity, r.tapTarget(44)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(r.size(12)),
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
                                borderRadius: BorderRadius.circular(r.size(12)),
                                child: Image.file(
                                  selectedImage!,
                                  height: r.size(150),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: r.size(8),
                                right: r.size(8),
                                child: GestureDetector(
                                  onTap: removeImage,
                                  child: Container(
                                    padding: EdgeInsets.all(r.size(6)),
                                    constraints: BoxConstraints(
                                      minWidth: r.tapTarget(44),
                                      minHeight: r.tapTarget(44),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: r.size(18),
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
                    left: r.size(24),
                    right: r.size(24),
                    bottom: MediaQuery.of(context).viewInsets.bottom + r.size(24),
                    top: r.size(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.grey.shade300,
                              width: r.size(1.5),
                            ),
                            padding: EdgeInsets.symmetric(vertical: r.size(16)),
                            minimumSize: Size(double.infinity, r.tapTarget(44)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: r.font(16, min: 14, max: 18),
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      ResponsiveGap.horizontal(12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : saveFood,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: r.size(16)),
                            minimumSize: Size(double.infinity, r.tapTarget(44)),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.size(12)),
                            ),
                            disabledBackgroundColor: AppColors.secondary
                                .withValues(alpha: 0.6),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: r.size(20),
                                  width: r.size(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Add Food',
                                  style: TextStyle(
                                    fontSize: r.font(16, min: 14, max: 18),
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

  void _confirmAddFood(
    String foodName,
    int calories,
    String mealType, {
    double? grams,
    String? imageUrl,
  }) async {
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
        // Track meal logging and calories for achievements
        try {
          await UserAchievementService.trackMealLogging(calories: calories);
        } catch (e) {
          // Don't block the success flow if achievement tracking fails
        }

        // Refresh the meal section to show updates
        await _mealsSectionKey.currentState?.loadMealData();

        // Refresh the calorie tracker header
        _calorieTrackerKey.currentState?.loadCalorieData();

        if (widget.onCaloriesUpdated != null) {
          widget.onCaloriesUpdated!();
        }

        // Show success feedback after refresh
        if (mounted) {
          final r = context.responsive;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.size(4)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: r.size(16),
                    ),
                  ),
                  ResponsiveGap.horizontal(12),
                  Text('Successfully added!', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.size(12)),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          final r = context.responsive;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add $foodName. Please try again.', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.size(12)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final r = context.responsive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding $foodName. Please try again.', style: TextStyle(fontSize: r.font(14, min: 12, max: 16))),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(12)),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (!hasChallenge) {
      return _buildNoChallengeUI();
    }
    return _buildMainFoodPage();
  }

  Widget _buildNoChallengeUI() {
    final r = context.responsive;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary.withValues(alpha: 0.08),
              Colors.white,
              AppColors.secondary.withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.size(24.0)),
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
                          width: r.size(200),
                          height: r.size(200),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.2),
                                AppColors.secondary.withValues(alpha: 0.1),
                                AppColors.secondary.withValues(alpha: 0.05),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.25),
                                blurRadius: r.size(40),
                                spreadRadius: r.size(5),
                                offset: Offset(0, r.size(10)),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: r.size(160),
                                height: r.size(160),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(alpha: 0.3),
                                    width: r.size(2),
                                  ),
                                ),
                              ),
                              Container(
                                width: r.size(120),
                                height: r.size(120),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.secondary.withValues(alpha: 0.2),
                                      AppColors.secondary.withValues(alpha: 0.15),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: r.size(60),
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

                ResponsiveGap.vertical(48),

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
                            fontSize: r.font(32, min: 24, max: 36),
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                            height: 1.2,
                            letterSpacing: r.size(-0.5),
                          ),
                        ),
                        ResponsiveGap.vertical(16),
                        Container(
                          constraints: BoxConstraints(maxWidth: r.size(320)),
                          child: Text(
                            'Create a challenge to unlock food logging, personalized recommendations, and meal tracking!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.font(16, min: 14, max: 18),
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
                      borderRadius: BorderRadius.circular(r.size(16)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: r.size(20),
                          offset: Offset(0, r.size(8)),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _navigateToCreateChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: r.size(18)),
                        minimumSize: Size(double.infinity, r.tapTarget(44)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.size(16)),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(r.size(6)),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.size(8)),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: r.size(20),
                              color: Colors.white,
                            ),
                          ),
                          ResponsiveGap.horizontal(12),
                          Text(
                            'Create Your First Challenge',
                            style: TextStyle(
                              fontSize: r.font(17, min: 15, max: 19),
                              fontWeight: FontWeight.w700,
                              letterSpacing: r.size(-0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                ResponsiveGap.vertical(16),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: TextButton.icon(
                    onPressed: _showChallengeExamples,
                    style: TextButton.styleFrom(
                      minimumSize: Size(r.tapTarget(44), r.tapTarget(44)),
                    ),
                    icon: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: r.size(18),
                      color: AppColors.secondary,
                    ),
                    label: Text(
                      'View challenge ideas',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: r.font(15, min: 13, max: 17),
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
    final r = context.responsive;
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.size(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calorie Tracker Header
            CalorieTrackerHeader(
              key: _calorieTrackerKey,
              currentChallenge: widget.currentChallenge,
            ),

            // Recommended Foods
            RecommendedFoods(
              onFoodTapped: (foodName, calories) {
                _addRecommendedFoodToMeal(foodName, calories);
              },
            ),

            // Meals Section
            MealsSection(
              key: _mealsSectionKey,
              onCaloriesUpdated: () async {
                // Refresh the calorie tracker header
                _calorieTrackerKey.currentState?.loadCalorieData();
                // Also update home page trackers
                widget.onCaloriesUpdated?.call();
              },
              challengeId: widget.currentChallenge?.id,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateChallenge() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CreateChallengeSheet(onChallengeCreated: _onChallengeCreated),
    );
  }

  void _showChallengeExamples() {
    final r = context.responsive;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(r.size(24))),
        ),
        padding: EdgeInsets.all(r.size(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: r.size(40),
                height: r.size(4),
                margin: EdgeInsets.only(bottom: r.size(20)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(r.size(2)),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(r.size(10)),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.size(12)),
                  ),
                  child: Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppColors.secondary,
                    size: r.size(24),
                  ),
                ),
                ResponsiveGap.horizontal(12),
                Text(
                  'Challenge Ideas',
                  style: TextStyle(
                    fontSize: r.font(24, min: 20, max: 26),
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            ResponsiveGap.vertical(24),
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
            ResponsiveGap.vertical(24),
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
                  padding: EdgeInsets.symmetric(vertical: r.size(16)),
                  minimumSize: Size(double.infinity, r.tapTarget(44)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.size(14)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Create My Challenge',
                  style: TextStyle(fontSize: r.font(16, min: 14, max: 18), fontWeight: FontWeight.w700),
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
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    final r = context.responsive;
    return Container(
      margin: EdgeInsets.only(bottom: r.size(16)),
      padding: EdgeInsets.all(r.size(16)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.size(16)),
        border: Border.all(color: color.withValues(alpha: 0.2), width: r.size(1.5)),
      ),
      child: Row(
        children: [
          Container(
            width: r.size(48),
            height: r.size(48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.15)],
              ),
              borderRadius: BorderRadius.circular(r.size(12)),
            ),
            child: Icon(icon, color: color, size: r.size(24)),
          ),
          ResponsiveGap.horizontal(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.font(16, min: 14, max: 18),
                  ),
                ),
                ResponsiveGap.vertical(4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: r.font(14, min: 12, max: 16),
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
