import 'dart:convert';
import 'package:http/http.dart' as http;

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  static const String _apiKey = '8bf544f05b374c6491f2d6f32980d39e'; // Replace with your key

  // Get meal-specific food recommendations
  static Future<List<RecommendedFood>> getRecommendedFoods({
    required String mealType, // breakfast, lunch, dinner, snack
    int number = 6,
  }) async {
    try {
      final String endpoint;
      final Map<String, String> queryParams = {
        'apiKey': _apiKey,
        'number': number.toString(),
        'addRecipeInformation': 'true',
        'addRecipeNutrition': 'true',
        'fillIngredients': 'true',
      };

      // Different endpoints for different meal types
      switch (mealType.toLowerCase()) {
        case 'breakfast':
          endpoint = '/recipes/complexSearch';
          queryParams.addAll({
            'type': 'breakfast',
            'sort': 'popularity',
            'maxCalories': '400',
          });
          break;
        case 'lunch':
          endpoint = '/recipes/complexSearch';
          queryParams.addAll({
            'type': 'main course',
            'sort': 'popularity',
            'minCalories': '300',
            'maxCalories': '600',
          });
          break;
        case 'dinner':
          endpoint = '/recipes/complexSearch';
          queryParams.addAll({
            'type': 'main course',
            'sort': 'popularity',
            'minCalories': '400',
            'maxCalories': '800',
          });
          break;
        case 'snack':
          endpoint = '/recipes/complexSearch';
          queryParams.addAll({
            'type': 'snack',
            'sort': 'popularity',
            'maxCalories': '200',
          });
          break;
        default:
          endpoint = '/recipes/complexSearch';
          queryParams.addAll({
            'sort': 'popularity',
          });
      }

      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        return results.map((item) => RecommendedFood.fromSpoonacularJson(item)).toList();
      } else {
        throw Exception('Failed to fetch recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching recommendations: $e');
    }
  }

  // Get ingredient-based recommendations (simpler foods)
  static Future<List<RecommendedFood>> getIngredientRecommendations({
    required String mealType,
    int number = 6,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'apiKey': _apiKey,
        'number': number.toString(),
        'ranking': '2', // Sort by popularity
      };

      // Different ingredients for different times
      List<String> ingredients = _getIngredientsForMealType(mealType);
      queryParams['ingredients'] = ingredients.join(',');

      final uri = Uri.parse('$_baseUrl/food/ingredients/search').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        // For each ingredient, get nutrition info
        List<RecommendedFood> foods = [];
        for (var item in results.take(number)) {
          try {
            final nutritionInfo = await getIngredientNutrition(item['id']);
            foods.add(RecommendedFood.fromIngredientJson(item, nutritionInfo));
          } catch (e) {
            // Skip this ingredient if nutrition fetch fails
            continue;
          }
        }
        return foods;
      } else {
        throw Exception('Failed to fetch ingredient recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ingredient recommendations: $e');
    }
  }

  // Get nutrition info for a specific ingredient
  static Future<Map<String, dynamic>> getIngredientNutrition(int ingredientId) async {
    try {
      final uri = Uri.parse('$_baseUrl/food/ingredients/$ingredientId/information').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'amount': '100',
          'unit': 'grams',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['nutrition'] ?? {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Helper method to get ingredients based on meal type and time
  static List<String> _getIngredientsForMealType(String mealType) {
    final now = DateTime.now();
    final hour = now.hour;

    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return ['oats', 'banana', 'eggs', 'yogurt', 'berries', 'milk'];
      case 'lunch':
        return ['chicken breast', 'salmon', 'quinoa', 'broccoli', 'spinach', 'avocado'];
      case 'dinner':
        return ['lean beef', 'sweet potato', 'brussels sprouts', 'brown rice', 'tofu'];
      case 'snack':
        if (hour < 15) {
          return ['almonds', 'apple', 'carrots', 'hummus']; // Afternoon snacks
        } else {
          return ['greek yogurt', 'berries', 'dark chocolate']; // Evening snacks
        }
      default:
        return ['apple', 'banana', 'chicken', 'broccoli', 'rice'];
    }
  }

  // Determine meal type based on current time
  static String getCurrentMealType() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) {
      return 'breakfast';
    } else if (hour >= 11 && hour < 15) {
      return 'lunch';
    } else if (hour >= 15 && hour < 18) {
      return 'snack';
    } else {
      return 'dinner';
    }
  }

  // Get meal type display name
  static String getMealTypeDisplayName(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snacks';
      default:
        return 'Foods';
    }
  }
}

// Model for recommended food
class RecommendedFood {
  final int id;
  final String name;
  final String image;
  final double calories;
  final String source; // 'spoonacular' or 'ingredient'

  RecommendedFood({
    required this.id,
    required this.name,
    required this.image,
    required this.calories,
    required this.source,
  });

  // Create from Spoonacular recipe API response
  factory RecommendedFood.fromSpoonacularJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'] ?? {};
    final nutrients = nutrition['nutrients'] as List<dynamic>? ?? [];

    double getCalories() {
      final nutrient = nutrients.firstWhere(
            (n) => n['name'].toString().toLowerCase().contains('calories'),
        orElse: () => {'amount': 0.0},
      );
      return (nutrient['amount'] ?? 0.0).toDouble();
    }

    return RecommendedFood(
      id: json['id'] ?? 0,
      name: json['title'] ?? 'Unknown Food',
      image: json['image'] ?? '',
      calories: getCalories(),
      source: 'spoonacular',
    );
  }

  // Create from ingredient API response
  factory RecommendedFood.fromIngredientJson(Map<String, dynamic> json, Map<String, dynamic> nutrition) {
    final nutrients = nutrition['nutrients'] as List<dynamic>? ?? [];

    double getCalories() {
      final nutrient = nutrients.firstWhere(
            (n) => n['name'].toString().toLowerCase().contains('calories'),
        orElse: () => {'amount': 0.0},
      );
      return (nutrient['amount'] ?? 0.0).toDouble();
    }

    return RecommendedFood(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Food',
      image: 'https://spoonacular.com/cdn/ingredients_250x250/${json['image'] ?? ''}',
      calories: getCalories(),
      source: 'ingredient',
    );
  }

  String get caloriesText => '${calories.round()} kcal/100g';
}