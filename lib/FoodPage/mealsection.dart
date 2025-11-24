import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'add_food_sheet.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/services/NotificationHelper.dart'; // ✅ Changed from notification_service
import '../app_text_styles.dart';
import '../utils/responsive_utils.dart';
import '../widgets/responsive_widgets.dart';

class MealsSection extends StatefulWidget {
  final VoidCallback? onCaloriesUpdated; // Add callback for tracker updates
  final String? challengeId;

  const MealsSection({super.key, this.onCaloriesUpdated, this.challengeId});

  @override
  State<MealsSection> createState() => MealsSectionState();
}

class MealsSectionState extends State<MealsSection> {
  final DateTime _currentDate = DateTime.now();
  Map<String, List<FoodEntry>> _mealEntries = {};
  Map<String, int> _mealCalories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMealData();
  }

  Future<void> loadMealData() async {
    // Only show loading screen on initial load, not on refresh
    bool isInitialLoad = _mealEntries.isEmpty && _mealCalories.isEmpty;

    if (isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      if (widget.challengeId == null) {
        setState(() {
          _mealEntries = {};
          _mealCalories = {};
          _isLoading = false;
        });
        return;
      }

      // Load from Firebase
      final foodLogs = await FoodLogService.getFoodLogsForDate(
        _currentDate,
        challengeId: widget.challengeId!,
      );

      final meals = ['Snack', 'Breakfast', 'Lunch', 'Dinner'];
      Map<String, List<FoodEntry>> entries = {};
      Map<String, int> calories = {};

      // Group Firebase data by meal type
      for (String meal in meals) {
        final mealLogs = foodLogs.where((log) => log.mealType == meal);
        final mealLog = mealLogs.isNotEmpty ? mealLogs.first : null;
        entries[meal] = mealLog?.entries ?? [];
        calories[meal] = mealLog?.totalCalories.round() ?? 0;
      }

      if (mounted) {
        setState(() {
          _mealEntries = entries;
          _mealCalories = calories;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Log error (replace with proper logging framework in production)
      if (mounted) {
        setState(() => _isLoading = false);

        final r = context.responsive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to load meal data. Please check your connection.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(8)),
            ),
          ),
        );
      }
    }
  }

  void _onFoodAdded(
      String foodName,
      int calories,
      String mealType, {
        double? grams,
        String? imageUrl,
      }) async {
    try {
      // Create new food entry
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

      if (widget.challengeId == null) {
        throw Exception('No active challenge');
      }

      // Save to Firebase
      final success = await FoodLogService.addFoodEntry(
        _currentDate,
        mealType,
        foodEntry,
        challengeId: widget.challengeId!,
      );

      if (success) {
        // Show success feedback in app
        if (mounted) {
          final r = context.responsive;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully added to $mealType!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.size(8)),
              ),
            ),
          );
        }

        // ✅ FIXED: Only save to NotificationPage (Firestore), no popup notification
        await NotificationHelper.createMealLoggedNotification(
          mealType,
          calories: calories,
        );

        // Reload the meal data to show the new entry
        await loadMealData();

        // Notify parent (tracker) that calories have been updated
        if (widget.onCaloriesUpdated != null) {
          widget.onCaloriesUpdated!();
        }
      } else {
        throw Exception('Failed to save to Firebase');
      }
    } catch (e) {
      if (mounted) {
        final r = context.responsive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save $foodName. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(8)),
            ),
          ),
        );
      }
    }
  }

  void _removeFoodEntry(FoodEntry entry) async {
    try {
      if (widget.challengeId == null) {
        throw Exception('No active challenge');
      }

      // Delete the image from Cloud Storage if it exists
      if (entry.imageUrl != null) {
        await ImageStorageService.deleteImage(entry.imageUrl!);
      }

      // Find the meal log containing this entry and remove it
      final foodLogs = await FoodLogService.getFoodLogsForDate(
        _currentDate,
        challengeId: widget.challengeId!,
      );

      // Find which meal contains this entry
      FoodLog? targetMeal;
      for (final log in foodLogs) {
        if (log.entries.any((e) => e.id == entry.id)) {
          targetMeal = log;
          break;
        }
      }

      if (targetMeal != null) {
        // Remove the entry from the meal
        final updatedEntries = targetMeal.entries
            .where((e) => e.id != entry.id)
            .toList();

        bool success;
        if (updatedEntries.isEmpty) {
          // Delete the entire meal if no entries left
          success = await FoodLogService.deleteFoodLog(
            targetMeal.id,
            challengeId: widget.challengeId!,
          );
        } else {
          // Update the meal with remaining entries
          final updatedMeal = targetMeal.copyWith(
            entries: updatedEntries,
            updatedAt: DateTime.now(),
          );
          success = await FoodLogService.updateFoodLog(
            updatedMeal,
            challengeId: widget.challengeId!,
          );
        }

        if (success) {
          // Show success feedback
          if (mounted) {
            final r = context.responsive;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entry.foodName} removed successfully'),
                backgroundColor: AppColors.secondary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.size(8)),
                ),
              ),
            );
          }

          await loadMealData();

          // Notify parent (tracker) that calories have been updated
          if (widget.onCaloriesUpdated != null) {
            widget.onCaloriesUpdated!();
          }
        } else {
          throw Exception('Failed to remove from Firebase');
        }
      }
    } catch (e) {
      // Log error (replace with proper logging framework in production)
      if (mounted) {
        final r = context.responsive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove ${entry.foodName}. Please try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(8)),
            ),
          ),
        );
      }
    }
  }

  // Get current meal type based on time
  String _getCurrentMealType() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) {
      return 'Breakfast';
    } else if (hour >= 11 && hour < 15) {
      return 'Lunch';
    } else if (hour >= 15 && hour < 18) {
      return 'Snack';
    } else {
      return 'Dinner';
    }
  }

  List<Map<String, dynamic>> _getOrderedMeals() {
    final currentMeal = _getCurrentMealType();
    final allMeals = [
      {
        "name": "Breakfast",
        "calories": "${_mealCalories['Breakfast'] ?? 0} calories",
        "icon": "assets/icons/breakfast.svg",
        "isRecommended": currentMeal == "Breakfast",
        "priority": currentMeal == "Breakfast" ? 1 : 2,
      },
      {
        "name": "Lunch",
        "calories": "${_mealCalories['Lunch'] ?? 0} calories",
        "icon": "assets/icons/lunch.svg",
        "isRecommended": currentMeal == "Lunch",
        "priority": currentMeal == "Lunch" ? 1 : 2,
      },
      {
        "name": "Snack",
        "calories": "${_mealCalories['Snack'] ?? 0} calories",
        "icon": "assets/icons/snack.svg",
        "isRecommended": currentMeal == "Snack",
        "priority": currentMeal == "Snack" ? 1 : 2,
      },
      {
        "name": "Dinner",
        "calories": "${_mealCalories['Dinner'] ?? 0} calories",
        "icon": "assets/icons/dinner.svg",
        "isRecommended": currentMeal == "Dinner",
        "priority": currentMeal == "Dinner" ? 1 : 2,
      },
    ];

    // Sort by priority (current meal first), then by time order
    allMeals.sort((a, b) {
      if (a['priority'] != b['priority']) {
        return (a['priority'] as int).compareTo(b['priority'] as int);
      }
      // If same priority, maintain time order
      const timeOrder = ['Breakfast', 'Lunch', 'Snack', 'Dinner'];
      return timeOrder
          .indexOf(a['name'] as String)
          .compareTo(timeOrder.indexOf(b['name'] as String));
    });

    return allMeals;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (_isLoading) {
      return const Center(child: FitCheckLoader());
    }

    final meals = _getOrderedMeals();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Meals", style: AppTextStyles.heading2),
            Row(
              children: [
                Text(
                  "Today • ${_formatDate(_currentDate)}",
                  style: TextStyle(
                    fontSize: r.font(14, min: 12, max: 16),
                    color: Colors.grey,
                  ),
                ),
                ResponsiveGap.horizontal(8),
                ResponsiveIconButton(
                  onPressed: loadMealData,
                  icon: Icons.refresh,
                  iconSize: 20,
                  minTapTarget: 44,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),

        ResponsiveGap.vertical(12),
        ...meals.map(
              (meal) => _MealCard(
            name: meal["name"] as String,
            calories: meal["calories"] as String,
            iconPath: meal["icon"] as String,
            isRecommended: meal["isRecommended"] as bool,
            foodEntries: _mealEntries[meal["name"]] ?? [],
            challengeId: widget.challengeId,
            onFoodAdded: (foodName, calories, {grams, imageUrl}) =>
                _onFoodAdded(
                  foodName,
                  calories,
                  meal["name"] as String,
                  grams: grams,
                  imageUrl: imageUrl,
                ),
            onFoodRemoved: _removeFoodEntry,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _MealCard extends StatefulWidget {
  final String name;
  final String calories;
  final String iconPath;
  final bool isRecommended;
  final List<FoodEntry> foodEntries;
  final Function(
      String foodName,
      int calories, {
      double? grams,
      String? imageUrl,
      })
  onFoodAdded;
  final Function(FoodEntry entry) onFoodRemoved;
  final String? challengeId;

  const _MealCard({
    required this.name,
    required this.calories,
    required this.iconPath,
    required this.isRecommended,
    required this.foodEntries,
    required this.onFoodAdded,
    required this.onFoodRemoved,
    this.challengeId,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  void _confirmRemoveFood(BuildContext context, FoodEntry entry) {
    final r = context.responsive;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.size(16)),
        ),
        title: const Text('Remove Food'),
        content: Text('Remove ${entry.foodName} from your ${widget.name}?'),
        actions: [
          ResponsiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ResponsiveButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onFoodRemoved(entry);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      margin: EdgeInsets.only(bottom: r.size(12)),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isRecommended
              ? AppColors.secondary.withValues(alpha: 0.5)
              : Colors.black12,
          width: r.size(widget.isRecommended ? 2 : 1),
        ),
        borderRadius: BorderRadius.circular(r.size(12)),
        color: Colors.white,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: r.size(16),
            vertical: r.size(8),
          ),
          leading: Stack(
            children: [
              SvgPicture.asset(
                widget.iconPath,
                width: r.size(28),
                height: r.size(28),
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
              ),
              if (widget.isRecommended)
                Positioned(
                  top: r.size(1),
                  right: r.size(1),
                  child: Container(
                    width: r.size(10),
                    height: r.size(10),
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Text(
                widget.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: r.font(16, min: 14, max: 18),
                ),
              ),
              if (widget.isRecommended) ...[
                ResponsiveGap.horizontal(8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.size(6),
                    vertical: r.size(2),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(r.size(8)),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.font(10, min: 9, max: 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            widget.calories,
            style: TextStyle(
              fontSize: r.font(13, min: 11, max: 15),
              color: Colors.black54,
            ),
          ),
          trailing: Icon(Icons.keyboard_arrow_down, size: r.size(24)),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.size(16)),
              child: Divider(
                thickness: r.size(1),
                height: r.size(1),
                color: Colors.black26,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: r.size(16),
                vertical: r.size(8),
              ),
              child: Column(
                children: [
                  // Add Food Button
                  OutlinedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => AddFoodSheet(
                          mealName: widget.name,
                          challengeId: widget.challengeId,
                          onFoodAdded: (foodName, calories, {grams, imageUrl}) {
                            widget.onFoodAdded(
                              foodName,
                              calories,
                              grams: grams,
                              imageUrl: imageUrl,
                            );
                          },
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(r.tapTarget(45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.size(12)),
                      ),
                      side: BorderSide(color: Colors.grey, width: r.size(1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add ${widget.name}",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: r.font(14, min: 12, max: 16),
                          ),
                        ),
                        Icon(Icons.add, color: Colors.grey, size: r.size(24)),
                      ],
                    ),
                  ),
                  ResponsiveGap.vertical(12),

                  // Display logged foods or empty state
                  if (widget.foodEntries.isNotEmpty) ...[
                    Column(
                      children: widget.foodEntries
                          .map(
                            (entry) => Container(
                          margin: EdgeInsets.only(bottom: r.size(8)),
                          padding: EdgeInsets.all(r.size(12)),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(r.size(8)),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: r.size(1),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Show image thumbnail or default icon
                              if (entry.imageUrl != null &&
                                  entry.imageUrl!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    r.size(6),
                                  ),
                                  child: Image.network(
                                    entry.imageUrl!,
                                    width: r.size(60),
                                    height: r.size(80),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Container(
                                        width: r.size(60),
                                        height: r.size(80),
                                        color: Colors.grey.shade300,
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey.shade500,
                                          size: r.size(24),
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Container(
                                        width: r.size(60),
                                        height: r.size(80),
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                            loadingProgress
                                                .expectedTotalBytes !=
                                                null
                                                ? loadingProgress
                                                .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                                : null,
                                            strokeWidth: r.size(2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: r.size(60),
                                  height: r.size(80),
                                  padding: EdgeInsets.all(r.size(12)),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      r.size(6),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.restaurant,
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
                                      entry.foodName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: r.font(
                                          14,
                                          min: 12,
                                          max: 16,
                                        ),
                                      ),
                                    ),
                                    ResponsiveGap.vertical(2),
                                    Row(
                                      children: [
                                        Text(
                                          '${entry.totalCalories.round()} cal',
                                          style: TextStyle(
                                            fontSize: r.font(
                                              12,
                                              min: 10,
                                              max: 14,
                                            ),
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (entry.servingSize > 0) ...[
                                          Text(
                                            ' • ',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: r.font(
                                                12,
                                                min: 10,
                                                max: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${entry.servingSize.toStringAsFixed(0)}g',
                                            style: TextStyle(
                                              fontSize: r.font(
                                                12,
                                                min: 10,
                                                max: 14,
                                              ),
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ResponsiveIconButton(
                                onPressed: () =>
                                    _confirmRemoveFood(context, entry),
                                icon: Icons.remove_circle_outline,
                                color: Colors.red.shade400,
                                iconSize: 20,
                                minTapTarget: 44,
                              ),
                            ],
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No foods logged for ${widget.name.toLowerCase()} yet",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tap 'Add ${widget.name}' to get started",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}