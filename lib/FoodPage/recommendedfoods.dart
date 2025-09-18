import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/spoonacular_service.dart';

class RecommendedFoods extends StatefulWidget {
  final Function(String foodName, int calories)? onFoodTapped;

  const RecommendedFoods({
    super.key,
    this.onFoodTapped,
  });

  @override
  State<RecommendedFoods> createState() => _RecommendedFoodsState();
}

class _RecommendedFoodsState extends State<RecommendedFoods> {
  List<RecommendedFood> _recommendedFoods = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _currentMealType = '';

  @override
  void initState() {
    super.initState();
    _loadRecommendedFoods();
  }

  Future<void> _loadRecommendedFoods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentMealType = SpoonacularService.getCurrentMealType();
    });

    try {
      // Try to get ingredient-based recommendations first (simpler, more reliable)
      final foods = await SpoonacularService.getIngredientRecommendations(
        mealType: _currentMealType,
        number: 6,
      );

      setState(() {
        _recommendedFoods = foods;
        _isLoading = false;
      });
    } catch (e) {
      // If API fails, show fallback foods based on time
      setState(() {
        _recommendedFoods = _getFallbackFoods();
        _isLoading = false;
        _errorMessage = 'Using offline recommendations';
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
          id: 1, name: 'Oatmeal', image: '', calories: 389,
          protein: 16.9, carbs: 66.3, fat: 6.9, source: 'fallback',
        ),
        RecommendedFood(
          id: 2, name: 'Banana', image: '', calories: 89,
          protein: 1.1, carbs: 22.8, fat: 0.3, source: 'fallback',
        ),
        RecommendedFood(
          id: 3, name: 'Eggs', image: '', calories: 155,
          protein: 13.0, carbs: 1.1, fat: 11.0, source: 'fallback',
        ),
      ];
    } else if (hour >= 11 && hour < 15) {
      // Lunch foods
      return [
        RecommendedFood(
          id: 4, name: 'Chicken Breast', image: '', calories: 165,
          protein: 31.0, carbs: 0, fat: 3.6, source: 'fallback',
        ),
        RecommendedFood(
          id: 5, name: 'Quinoa', image: '', calories: 120,
          protein: 4.4, carbs: 22.0, fat: 1.9, source: 'fallback',
        ),
        RecommendedFood(
          id: 6, name: 'Broccoli', image: '', calories: 25,
          protein: 3.0, carbs: 5.0, fat: 0.4, source: 'fallback',
        ),
      ];
    } else if (hour >= 15 && hour < 18) {
      // Snack foods
      return [
        RecommendedFood(
          id: 7, name: 'Apple', image: '', calories: 52,
          protein: 0.3, carbs: 14.0, fat: 0.2, source: 'fallback',
        ),
        RecommendedFood(
          id: 8, name: 'Almonds', image: '', calories: 579,
          protein: 21.0, carbs: 22.0, fat: 50.0, source: 'fallback',
        ),
        RecommendedFood(
          id: 9, name: 'Greek Yogurt', image: '', calories: 100,
          protein: 17.0, carbs: 6.0, fat: 0.4, source: 'fallback',
        ),
      ];
    } else {
      // Dinner foods
      return [
        RecommendedFood(
          id: 10, name: 'Salmon', image: '', calories: 142,
          protein: 25.0, carbs: 0, fat: 4.4, source: 'fallback',
        ),
        RecommendedFood(
          id: 11, name: 'Sweet Potato', image: '', calories: 76,
          protein: 1.4, carbs: 17.0, fat: 0.1, source: 'fallback',
        ),
        RecommendedFood(
          id: 12, name: 'Brown Rice', image: '', calories: 123,
          protein: 2.3, carbs: 23.0, fat: 0.9, source: 'fallback',
        ),
      ];
    }
  }

  void _onFoodTapped(RecommendedFood food) {
    if (widget.onFoodTapped != null) {
      widget.onFoodTapped!(food.name, food.calories.round());
    }

    // Show food details
    _showFoodDetails(food);
  }

  void _showFoodDetails(RecommendedFood food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(food.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (food.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  food.image,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(height: 120, color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported)),
                ),
              ),
            const SizedBox(height: 16),
            _buildNutrientRow('Calories', '${food.calories.round()}', 'kcal'),
            _buildNutrientRow('Protein', food.protein.toStringAsFixed(1), 'g'),
            _buildNutrientRow('Carbs', food.carbs.toStringAsFixed(1), 'g'),
            _buildNutrientRow('Fat', food.fat.toStringAsFixed(1), 'g'),
            const SizedBox(height: 8),
            Text(
              'Values per 100g',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onFoodTapped != null) {
                widget.onFoodTapped!(food.name, food.calories.round());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add to Log'),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('$value$unit', style: TextStyle(color: AppColors.secondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recommended for ${SpoonacularService.getMealTypeDisplayName(_currentMealType)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                  ),
              ],
            ),
            IconButton(
              onPressed: _loadRecommendedFoods,
              icon: Icon(
                Icons.refresh,
                color: AppColors.secondary,
                size: 20,
              ),
              tooltip: 'Refresh recommendations',
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 160,
          child: _isLoading
              ? _buildLoadingState()
              : _buildFoodList(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return Container(
          width: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
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

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _recommendedFoods.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final food = _recommendedFoods[index];
        return GestureDetector(
          onTap: () => _onFoodTapped(food),
          child: Container(
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.3),
                        Colors.transparent
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
                        if (food.protein > 0)
                          Text(
                            '${food.protein.toStringAsFixed(1)}g protein',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Time-based indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getMealTypeColor().withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentMealType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFoodPlaceholder(String foodName) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.7),
            AppColors.secondary.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFoodIcon(foodName),
              color: Colors.white,
              size: 32,
            ),
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
    if (name.contains('chicken') || name.contains('meat')) return Icons.set_meal;
    if (name.contains('fish') || name.contains('salmon')) return Icons.set_meal;
    if (name.contains('apple') || name.contains('banana') || name.contains('fruit')) return Icons.apple;
    if (name.contains('rice') || name.contains('grain')) return Icons.grain;
    if (name.contains('egg')) return Icons.egg_alt;
    if (name.contains('milk') || name.contains('yogurt')) return Icons.local_drink;
    if (name.contains('vegetable') || name.contains('broccoli')) return Icons.grass;
    return Icons.restaurant_menu;
  }

  Color _getMealTypeColor() {
    switch (_currentMealType) {
      case 'breakfast': return Colors.orange;
      case 'lunch': return Colors.green;
      case 'snack': return Colors.purple;
      case 'dinner': return Colors.blue;
      default: return AppColors.secondary;
    }
  }
}