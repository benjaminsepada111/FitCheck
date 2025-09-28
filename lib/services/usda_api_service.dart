// Create file: lib/services/usda_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_models.dart';

class USDAApiService {
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  // Replace with your API key or leave empty for demo mode (with rate limits)
  static const String _apiKey = 'qLe1ZmPZocFJ6aM2N71IrZqsvNVs8ctsVHgHie6e';

  // Search for foods
  static Future<FoodSearchResponse> searchFoods({
    required String query,
    int pageSize = 25,
    int pageNumber = 1,
    List<String> dataType = const ['Foundation', 'SR Legacy', 'Branded'],
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
        return FoodSearchResponse.fromJson(data);
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