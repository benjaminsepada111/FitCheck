import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'add_food_sheet.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/color/colors.dart';

class MealsSection extends StatefulWidget {
  final VoidCallback? onCaloriesUpdated; // Add callback for tracker updates
  final String? challengeId;

  const MealsSection({
    super.key,
    this.onCaloriesUpdated,
    this.challengeId,
  });

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
    setState(() => _isLoading = true);

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
      final foodLogs = await FoodLogService.getFoodLogsForDate(_currentDate, challengeId: widget.challengeId!);

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

      setState(() {
        _mealEntries = entries;
        _mealCalories = calories;
        _isLoading = false;
      });
    } catch (e) {
      // Log error (replace with proper logging framework in production)
      debugPrint('Error loading meal data: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load meal data. Please check your connection.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }


  void _onFoodAdded(String foodName, int calories, String mealType, {double? grams, String? imageUrl}) async {
    try {
      // Create new food entry
      final foodEntry = FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fdcId: 0, // Set default fdcId since we're only tracking calories
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
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully added to $mealType!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }

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
      // Log error (replace with proper logging framework in production)
      debugPrint('Error adding food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save $foodName. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        debugPrint('🗑️ Deleting image from Cloud Storage: ${entry.imageUrl}');
        await ImageStorageService.deleteImage(entry.imageUrl!);
      }

      // Find the meal log containing this entry and remove it
      final foodLogs = await FoodLogService.getFoodLogsForDate(_currentDate, challengeId: widget.challengeId!);

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
        final updatedEntries = targetMeal.entries.where((e) => e.id != entry.id).toList();

        bool success;
        if (updatedEntries.isEmpty) {
          // Delete the entire meal if no entries left
          success = await FoodLogService.deleteFoodLog(targetMeal.id, challengeId: widget.challengeId!);
        } else {
          // Update the meal with remaining entries
          final updatedMeal = targetMeal.copyWith(
            entries: updatedEntries,
            updatedAt: DateTime.now(),
          );
          success = await FoodLogService.updateFoodLog(updatedMeal, challengeId: widget.challengeId!);
        }

        if (success) {
          // Show success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entry.foodName} removed successfully'),
                backgroundColor: AppColors.secondary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      debugPrint('Error removing food entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove ${entry.foodName}. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      return timeOrder.indexOf(a['name'] as String).compareTo(
        timeOrder.indexOf(b['name'] as String),
      );
    });


    return allMeals;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final meals = _getOrderedMeals();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Meals",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  "Today • ${_formatDate(_currentDate)}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: loadMealData,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh meals',
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...meals.map((meal) => _MealCard(
          name: meal["name"] as String,
          calories: meal["calories"] as String,
          iconPath: meal["icon"] as String,
          isRecommended: meal["isRecommended"] as bool,
          foodEntries: _mealEntries[meal["name"]] ?? [],
          challengeId: widget.challengeId,
          onFoodAdded: (foodName, calories, {grams, imageUrl}) => _onFoodAdded(
            foodName,
            calories,
            meal["name"] as String,
            grams: grams,
            imageUrl: imageUrl,
          ),
          onFoodRemoved: _removeFoodEntry,
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
  final Function(String foodName, int calories, {double? grams, String? imageUrl}) onFoodAdded;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Food'),
        content: Text('Remove ${entry.foodName} from your ${widget.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onFoodRemoved(entry);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isRecommended ? AppColors.secondary.withValues(alpha:0.5) : Colors.black12,
          width: widget.isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: widget.isRecommended ? AppColors.secondary.withValues(alpha:0.05) : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              SvgPicture.asset(
                widget.iconPath,
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
              ),
              if (widget.isRecommended)
                Positioned(
                  top: 1,
                  right: 1,

                  child: Container(
                    width: 10,
                    height: 10,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (widget.isRecommended) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            widget.calories,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                thickness: 1,
                height: 1,
                color: Colors.black26,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            widget.onFoodAdded(foodName, calories, grams: grams, imageUrl: imageUrl);
                          },
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add ${widget.name}",
                          style: const TextStyle(color: Colors.black),
                        ),
                        const Icon(Icons.add, color: Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Display logged foods or empty state
                  if (widget.foodEntries.isNotEmpty) ...[
                    Column(
                      children: widget.foodEntries.map((entry) =>
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                // Show image thumbnail or default icon
                                if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      entry.imageUrl!,
                                      width: 60,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 60,
                                          height: 80,
                                          color: Colors.grey.shade300,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey.shade500,
                                          ),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          width: 60,
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  Container(
                                    width: 60,
                                    height: 80,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.restaurant,
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
                                        entry.foodName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${entry.totalCalories.round()} cal',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (entry.servingSize > 0) ...[
                                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                                            Text(
                                              '${entry.servingSize.toStringAsFixed(0)}g',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _confirmRemoveFood(context, entry),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red.shade400,
                                  iconSize: 20,
                                  tooltip: 'Remove food',
                                ),
                              ],
                            ),
                          ),
                      ).toList(),
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