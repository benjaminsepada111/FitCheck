import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/food_models.dart';

class USDAApiService {
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  static String get _apiKey => EnvConfig.usdaApiKey;

  // Clean and simplify food names by removing unnecessary details
  static String cleanFoodName(String description) {
    String cleaned = description;

    // Convert to lowercase for processing
    cleaned = cleaned.toLowerCase();

    // Remove common unnecessary details
    final unnecessaryPatterns = [
      r',\s*with added vitamin [a-z]',
      r',\s*with vitamin [a-z]',
      r',\s*vitamin [a-z] added',
      r',\s*fortified',
      r',\s*enriched',
      r',\s*\d+\.?\d*%\s*fat',
      r',\s*\d+\.?\d*%\s*milk\s*fat',
      r',\s*reduced fat',
      r',\s*low fat',
      r',\s*fat free',
      r',\s*nonfat',
      r',\s*no salt added',
      r',\s*unsalted',
      r',\s*salted',
      r',\s*raw',
      r',\s*fresh',
      r',\s*frozen',
      r',\s*canned',
      r',\s*dried',
      r',\s*cooked',
      r',\s*boiled',
      r',\s*baked',
      r',\s*upc:.*',
      r'\(.*usda.*\)',
      r'\(.*ndb.*\)',
    ];

    for (final pattern in unnecessaryPatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // Simplify specific food types
    if (cleaned.contains('milk')) {
      if (cleaned.contains('whole')) {
        cleaned = 'milk, whole';
      } else if (cleaned.contains('skim') || cleaned.contains('nonfat')) {
        cleaned = 'milk, skim';
      } else if (cleaned.contains('low')) {
        cleaned = 'milk, low fat';
      } else if (cleaned.contains('2%') || cleaned.contains('reduced')) {
        cleaned = 'milk, 2% reduced fat';
      }
    }

    // Remove extra whitespace and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter of each word
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // Search for foods (now defaults to Foundation and SR Legacy only)
  static Future<FoodSearchResponse> searchFoods({
    required String query,
    int pageSize = 25,
    int pageNumber = 1,
    List<String> dataType = const ['Foundation', 'SR Legacy'],
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'query': query,
        'dataType': dataType,
        'pageSize': pageSize,
        'pageNumber': pageNumber,
        'sortBy': 'dataType.keyword',
        'sortOrder': 'asc',
      };

      final String url = _apiKey.isNotEmpty
          ? '$_baseUrl/foods/search?api_key=$_apiKey'
          : '$_baseUrl/foods/search';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final searchResponse = FoodSearchResponse.fromJson(data);

        // Clean food names and remove duplicates/branded items
        final cleanedFoods = <String, FoodSearchResult>{};

        for (final food in searchResponse.foods) {
          // Skip foods with zero calories
          if (food.calories <= 0) continue;

          // Skip foods that are clearly branded (have brandOwner)
          if (food.brandOwner != null && food.brandOwner!.isNotEmpty) continue;

          // Clean the food name
          final cleanedName = cleanFoodName(food.description);

          // Use cleaned name as key to deduplicate
          // Keep the first occurrence of each unique cleaned name
          if (!cleanedFoods.containsKey(cleanedName.toLowerCase())) {
            cleanedFoods[cleanedName.toLowerCase()] = FoodSearchResult(
              fdcId: food.fdcId,
              description: cleanedName,
              calories: food.calories,
              brandOwner: null,
              ingredients: null,
            );
          }
        }

        return FoodSearchResponse(
          foods: cleanedFoods.values.toList(),
          totalHits: cleanedFoods.length,
        );
      } else {
        throw Exception('Failed to search foods: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching foods: $e');
    }
  }

  // Get detailed food information by FDC ID
  static Future<FoodSearchResult> getFoodDetails({
    required int fdcId,
  }) async {
    try {
      String url = _apiKey.isNotEmpty
          ? '$_baseUrl/food/$fdcId?api_key=$_apiKey'
          : '$_baseUrl/food/$fdcId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return FoodSearchResult.fromJson(data);
      } else {
        throw Exception('Failed to get food details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting food details: $e');
    }
  }

  // Calculate calories for specific amount
  static double calculateCaloriesForAmount({
    required FoodSearchResult food,
    required double grams,
  }) {
    // USDA data is per 100g, so we calculate based on the amount
    final double factor = grams / 100.0;
    return food.calories * factor;
  }

  // Get popular food suggestions (you can customize this)
  static Future<List<FoodSearchResult>> getPopularFoods() async {
    final popularQueries = [
      'apple', 'banana', 'chicken breast', 'rice', 'bread',
      'egg', 'milk', 'cheese', 'salmon', 'broccoli'
    ];

    List<FoodSearchResult> popularFoods = [];

    for (String query in popularQueries.take(5)) { // Limit to avoid API quota
      try {
        final result = await searchFoods(query: query, pageSize: 1);
        if (result.foods.isNotEmpty) {
          popularFoods.add(result.foods.first);
        }
      } catch (e) {
        // Continue with other queries if one fails
        continue;
      }
    }

    return popularFoods;
  }

  // Helper method to format food description for display
  static String formatFoodDescription(FoodSearchResult food) {
    String description = food.description;

    // Add brand if available
    if (food.brandOwner != null && food.brandOwner!.isNotEmpty) {
      description = '${food.brandOwner} - $description';
    }

    return description;
  }

  // Helper method to get calorie summary text
  static String getCalorieSummary(FoodSearchResult food, double grams) {
    final calories = calculateCaloriesForAmount(food: food, grams: grams);
    return '${calories.round()} calories';
  }
}