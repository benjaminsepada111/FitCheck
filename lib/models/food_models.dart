// Create file: lib/models/food_models.dart

class FoodSearchResult {
  final int fdcId;
  final String description;
  final String? brandOwner;
  final String? ingredients;
  final double calories; // Calories per 100g

  FoodSearchResult({
    required this.fdcId,
    required this.description,
    this.brandOwner,
    this.ingredients,
    required this.calories,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    // Extract calories from foodNutrients if available
    double caloriesValue = 0.0;
    final foodNutrients = json['foodNutrients'] as List<dynamic>?;
    if (foodNutrients != null) {
      for (final nutrient in foodNutrients) {
        if (nutrient['nutrientId'] == 1008) { // Energy (kcal)
          caloriesValue = (nutrient['value'] ?? 0).toDouble();
          break;
        }
      }
    }

    return FoodSearchResult(
      fdcId: json['fdcId'] ?? 0,
      description: json['description'] ?? '',
      brandOwner: json['brandOwner'],
      ingredients: json['ingredients'],
      calories: caloriesValue,
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

  FoodEntry({
    required this.id,
    required this.fdcId,
    required this.foodName,
    required this.servingSize,
    required this.servingUnit,
    required this.caloriesPer100g,
  });

  // Calculate calories for the actual serving size
  double get totalCalories {
    return (caloriesPer100g * servingSize) / 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fdcId': fdcId,
      'foodName': foodName,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'caloriesPer100g': caloriesPer100g,
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
    );
  }

  FoodEntry copyWith({
    String? id,
    int? fdcId,
    String? foodName,
    double? servingSize,
    String? servingUnit,
    double? caloriesPer100g,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      fdcId: fdcId ?? this.fdcId,
      foodName: foodName ?? this.foodName,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
    );
  }
}