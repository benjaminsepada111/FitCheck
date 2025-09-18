// Create file: lib/models/food_models.dart

class FoodSearchResult {
  final int fdcId;
  final String description;
  final String? brandOwner;
  final String? ingredients;
  final List<FoodNutrient> foodNutrients;

  FoodSearchResult({
    required this.fdcId,
    required this.description,
    this.brandOwner,
    this.ingredients,
    this.foodNutrients = const [],
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      fdcId: json['fdcId'] ?? 0,
      description: json['description'] ?? '',
      brandOwner: json['brandOwner'],
      ingredients: json['ingredients'],
      foodNutrients: (json['foodNutrients'] as List<dynamic>?)
          ?.map((nutrient) => FoodNutrient.fromJson(nutrient))
          .toList() ?? [],
    );
  }

  // Get specific nutrient value
  double getNutrientValue(int nutrientId) {
    final nutrient = foodNutrients.firstWhere(
          (n) => n.nutrientId == nutrientId,
      orElse: () => FoodNutrient(nutrientId: nutrientId, value: 0.0),
    );
    return nutrient.value;
  }

  // Convenience getters for common nutrients (per 100g)
  double get calories => getNutrientValue(1008); // Energy (kcal)
  double get protein => getNutrientValue(1003); // Protein
  double get totalFat => getNutrientValue(1004); // Total fat
  double get carbs => getNutrientValue(1005); // Carbohydrates
  double get fiber => getNutrientValue(1079); // Fiber
  double get sugar => getNutrientValue(2000); // Total sugars
  double get sodium => getNutrientValue(1093); // Sodium (mg)
}

class FoodNutrient {
  final int nutrientId;
  final String? nutrientName;
  final double value;
  final String? unitName;

  FoodNutrient({
    required this.nutrientId,
    this.nutrientName,
    required this.value,
    this.unitName,
  });

  factory FoodNutrient.fromJson(Map<String, dynamic> json) {
    return FoodNutrient(
      nutrientId: json['nutrientId'] ?? 0,
      nutrientName: json['nutrientName'],
      value: (json['value'] ?? 0).toDouble(),
      unitName: json['unitName'],
    );
  }
}

class FoodSearchResponse {
  final List<FoodSearchResult> foods;
  final int totalHits;

  FoodSearchResponse({
    required this.foods,
    required this.totalHits,
  });

  factory FoodSearchResponse.fromJson(Map<String, dynamic> json) {
    return FoodSearchResponse(
      foods: (json['foods'] as List<dynamic>?)
          ?.map((food) => FoodSearchResult.fromJson(food))
          .toList() ?? [],
      totalHits: json['totalHits'] ?? 0,
    );
  }
}