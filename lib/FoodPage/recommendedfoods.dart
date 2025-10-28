import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/spoonacular_service.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import '../app_text_styles.dart';

class RecommendedFoods extends StatefulWidget {
  final Function(String foodName, int calories)? onFoodTapped;

  const RecommendedFoods({super.key, this.onFoodTapped});

  @override
  State<RecommendedFoods> createState() => _RecommendedFoodsState();
}

class _RecommendedFoodsState extends State<RecommendedFoods> {
  List<RecommendedFood> _recommendedFoods = [];
  bool _isLoading = true;
  String _currentMealType = '';

  @override
  void initState() {
    super.initState();
    _loadRecommendedFoods();
  }

  Future<void> _loadRecommendedFoods() async {
    setState(() {
      _isLoading = true;
      _currentMealType = SpoonacularService.getCurrentMealType();
    });

    try {
      // Try to get ingredient-based recommendations first (simpler, more reliable)
      final foods = await SpoonacularService.getIngredientRecommendations(
        mealType: _currentMealType,
        number: 6,
      );

      if (foods.isNotEmpty) {
        setState(() {
          _recommendedFoods = foods;
          _isLoading = false;
        });
      } else {
        throw Exception('No foods returned from API');
      }
    } catch (e) {
      // Try the recipe-based recommendations as fallback
      try {
        final recipeFoods = await SpoonacularService.getRecommendedFoods(
          mealType: _currentMealType,
          number: 3,
        );

        if (recipeFoods.isNotEmpty) {
          setState(() {
            _recommendedFoods = recipeFoods;
            _isLoading = false;
          });
          return;
        }
      } catch (e2) {
        // Both API calls failed
      }

      // If both API calls fail, show curated fallback foods
      setState(() {
        _recommendedFoods = _getFallbackFoods();
        _isLoading = false;
      });
    }
  }

  List<RecommendedFood> _getFallbackFoods() {
    // Fallback foods based on current time
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) {
      // Breakfast foods
      return [
        RecommendedFood(
          id: 1,
          name: 'Oatmeal',
          image: '',
          calories: 389,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 2,
          name: 'Banana',
          image: '',
          calories: 89,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 3,
          name: 'Eggs',
          image: '',
          calories: 155,
          source: 'fallback',
        ),
      ];
    } else if (hour >= 11 && hour < 15) {
      // Lunch foods
      return [
        RecommendedFood(
          id: 4,
          name: 'Chicken Breast',
          image: '',
          calories: 165,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 5,
          name: 'Quinoa',
          image: '',
          calories: 120,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 6,
          name: 'Broccoli',
          image: '',
          calories: 25,
          source: 'fallback',
        ),
      ];
    } else if (hour >= 15 && hour < 18) {
      // Snack foods
      return [
        RecommendedFood(
          id: 7,
          name: 'Apple',
          image: '',
          calories: 52,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 8,
          name: 'Almonds',
          image: '',
          calories: 579,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 9,
          name: 'Greek Yogurt',
          image: '',
          calories: 100,
          source: 'fallback',
        ),
      ];
    } else {
      // Dinner foods
      return [
        RecommendedFood(
          id: 10,
          name: 'Salmon',
          image: '',
          calories: 142,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 11,
          name: 'Sweet Potato',
          image: '',
          calories: 76,
          source: 'fallback',
        ),
        RecommendedFood(
          id: 12,
          name: 'Brown Rice',
          image: '',
          calories: 123,
          source: 'fallback',
        ),
      ];
    }
  }

  void _onFoodTapped(RecommendedFood food) {
    if (widget.onFoodTapped != null) {
      widget.onFoodTapped!(food.name, food.calories.round());
    }
    // Note: Food details dialog is now handled by the parent component
    // to avoid duplicate dialogs and overlay issues
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Text("Recommended Foods", style: AppTextStyles.heading2),
        ),

        // Food List
        SizedBox(
          height: 160,
          child: _isLoading ? _buildLoadingState() : _buildFoodList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        for (int index = 0; index < 3; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: FitCheckLoader()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFoodList() {
    if (_recommendedFoods.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              'No recommendations available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loadRecommendedFoods,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Take only first 3 items to fit on screen
    final displayFoods = _recommendedFoods.take(3).toList();

    return Row(
      children: [
        for (int index = 0; index < displayFoods.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(child: _buildFoodCard(displayFoods[index])),
        ],
      ],
    );
  }

  Widget _buildFoodCard(RecommendedFood food) {
    return GestureDetector(
      onTap: () => _onFoodTapped(food),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Image or placeholder
            if (food.image.isNotEmpty && food.source != 'fallback')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  food.image,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFoodPlaceholder(food.name),
                ),
              )
            else
              _buildFoodPlaceholder(food.name),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Food info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      food.caloriesText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodPlaceholder(String foodName) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.7),
            AppColors.secondary.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getFoodIcon(foodName), color: Colors.white, size: 32),
            const SizedBox(height: 4),
            Text(
              foodName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('chicken') || name.contains('meat'))
      return Icons.set_meal;
    if (name.contains('fish') || name.contains('salmon')) return Icons.set_meal;
    if (name.contains('apple') ||
        name.contains('banana') ||
        name.contains('fruit'))
      return Icons.apple;
    if (name.contains('rice') || name.contains('grain')) return Icons.grain;
    if (name.contains('egg')) return Icons.egg_alt;
    if (name.contains('milk') || name.contains('yogurt'))
      return Icons.local_drink;
    if (name.contains('vegetable') || name.contains('broccoli'))
      return Icons.grass;
    return Icons.restaurant_menu;
  }
}
