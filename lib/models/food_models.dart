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

class FoodLog {
  final String id;
  final DateTime date;
  final String mealType; // breakfast, lunch, dinner, snack
  final List<FoodEntry> entries;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculate total calories for this meal
  double get totalCalories {
    return entries.fold(0.0, (sum, entry) => sum + entry.totalCalories);
  }

  // Calculate total macros
  double get totalProtein {
    return entries.fold(0.0, (sum, entry) => sum + entry.totalProtein);
  }

  double get totalFat {
    return entries.fold(0.0, (sum, entry) => sum + entry.totalFat);
  }

  double get totalCarbs {
    return entries.fold(0.0, (sum, entry) => sum + entry.totalCarbs);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mealType': mealType,
      'entries': entries.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'],
      date: DateTime.parse(json['date']),
      mealType: json['mealType'],
      entries: (json['entries'] as List<dynamic>)
          .map((e) => FoodEntry.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  FoodLog copyWith({
    String? id,
    DateTime? date,
    String? mealType,
    List<FoodEntry>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FoodEntry {
  final String id;
  final int fdcId;
  final String foodName;
  final double servingSize; // in grams
  final String servingUnit; // e.g., "cup", "piece", "grams"
  final double caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;

  FoodEntry({
    required this.id,
    required this.fdcId,
    required this.foodName,
    required this.servingSize,
    required this.servingUnit,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
  });

  // Calculate nutritional values for the actual serving size
  double get totalCalories {
    return (caloriesPer100g * servingSize) / 100;
  }

  double get totalProtein {
    return (proteinPer100g * servingSize) / 100;
  }

  double get totalFat {
    return (fatPer100g * servingSize) / 100;
  }

  double get totalCarbs {
    return (carbsPer100g * servingSize) / 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fdcId': fdcId,
      'foodName': foodName,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'fatPer100g': fatPer100g,
      'carbsPer100g': carbsPer100g,
    };
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'],
      fdcId: json['fdcId'],
      foodName: json['foodName'],
      servingSize: json['servingSize'].toDouble(),
      servingUnit: json['servingUnit'],
      caloriesPer100g: json['caloriesPer100g'].toDouble(),
      proteinPer100g: json['proteinPer100g'].toDouble(),
      fatPer100g: json['fatPer100g'].toDouble(),
      carbsPer100g: json['carbsPer100g'].toDouble(),
    );
  }

  // Create FoodEntry from FoodSearchResult
  static FoodEntry fromSearchResult(
    FoodSearchResult searchResult,
    double servingSize,
    String servingUnit,
  ) {
    return FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fdcId: searchResult.fdcId,
      foodName: searchResult.description,
      servingSize: servingSize,
      servingUnit: servingUnit,
      caloriesPer100g: searchResult.calories,
      proteinPer100g: searchResult.protein,
      fatPer100g: searchResult.totalFat,
      carbsPer100g: searchResult.carbs,
    );
  }

  FoodEntry copyWith({
    String? id,
    int? fdcId,
    String? foodName,
    double? servingSize,
    String? servingUnit,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? carbsPer100g,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      fdcId: fdcId ?? this.fdcId,
      foodName: foodName ?? this.foodName,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
    );
  }
}