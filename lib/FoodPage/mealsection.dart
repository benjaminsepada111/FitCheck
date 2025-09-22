import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'add_food_sheet.dart';
import 'package:capstone_project/services/food_storage_service.dart';

class MealsSection extends StatefulWidget {
  final VoidCallback? onCaloriesUpdated; // Add callback for tracker updates

  const MealsSection({
    super.key,
    this.onCaloriesUpdated,
  });

  @override
  State<MealsSection> createState() => _MealsSectionState();
}

class _MealsSectionState extends State<MealsSection> {
  final DateTime _currentDate = DateTime.now();
  Map<String, List<FoodEntry>> _mealEntries = {};
  Map<String, int> _mealCalories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMealData();
  }

  Future<void> _loadMealData() async {
    setState(() => _isLoading = true);

    final meals = ['Snack', 'Breakfast', 'Lunch', 'Dinner'];
    Map<String, List<FoodEntry>> entries = {};
    Map<String, int> calories = {};

    for (String meal in meals) {
      entries[meal] = await FoodStorageService.getFoodEntriesForMeal(meal, _currentDate);
      calories[meal] = await FoodStorageService.getTotalCaloriesForMeal(meal, _currentDate);
    }

    setState(() {
      _mealEntries = entries;
      _mealCalories = calories;
      _isLoading = false;
    });
  }

  void _onFoodAdded(String foodName, int calories, String mealType, {double? grams, Map<String, double>? nutrition}) async {
    // Create and store the food entry
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: foodName,
      calories: calories,
      mealType: mealType,
      dateLogged: _currentDate,
      grams: grams,
      nutrition: nutrition,
    );

    await FoodStorageService.storeFoodEntry(entry);
    await FoodStorageService.updateMealRecommendations(mealType, foodName);

    // Reload the meal data to show the new entry
    await _loadMealData();

    // Notify parent (tracker) that calories have been updated
    if (widget.onCaloriesUpdated != null) {
      widget.onCaloriesUpdated!();
    }
  }

  void _removeFoodEntry(FoodEntry entry) async {
    await FoodStorageService.removeFoodEntry(entry.id, _currentDate);
    await _loadMealData();

    // Notify parent (tracker) that calories have been updated
    if (widget.onCaloriesUpdated != null) {
      widget.onCaloriesUpdated!();
    }
  }

  List<Map<String, dynamic>> _getOrderedMeals() {
    final currentMeal = FoodStorageService.getCurrentMealType();
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
            Text(
              "Today • ${_formatDate(_currentDate)}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          onFoodAdded: (foodName, calories, {grams, nutrition}) => _onFoodAdded(
            foodName,
            calories,
            meal["name"] as String,
            grams: grams,
            nutrition: nutrition,
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
  final Function(String foodName, int calories, {double? grams, Map<String, double>? nutrition}) onFoodAdded;
  final Function(FoodEntry entry) onFoodRemoved;

  const _MealCard({
    required this.name,
    required this.calories,
    required this.iconPath,
    required this.isRecommended,
    required this.foodEntries,
    required this.onFoodAdded,
    required this.onFoodRemoved,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isRecommended ? Colors.orange.withOpacity(0.5) : Colors.black12,
          width: widget.isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: widget.isRecommended ? Colors.orange.withOpacity(0.05) : null,
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
                color: Colors.black87,
              ),
              if (widget.isRecommended)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
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
                    color: Colors.orange,
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
                          onFoodAdded: (foodName, calories, {grams, nutrition}) {
                            widget.onFoodAdded(foodName, calories, grams: grams, nutrition: nutrition);
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${entry.calories} cal',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (entry.grams != null) ...[
                                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                                            Text(
                                              '${entry.grams!.toStringAsFixed(0)}g',
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
                                  onPressed: () => widget.onFoodRemoved(entry),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red.shade400,
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ),
                      ).toList(),
                    ),
                  ] else ...[
                    const Text(
                      "No foods logged yet",
                      style: TextStyle(color: Colors.black54),
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