import 'package:flutter/material.dart';
import 'package:capstone_project/FoodPage/foodlogger.dart';
import 'package:capstone_project/FoodPage/mealsection.dart';
import 'package:capstone_project/FoodPage/recommendedfoods.dart';

// --- Food Page ---
class FoodPage extends StatelessWidget {
  const FoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          FoodLogger(),
          SizedBox(height: 20),
          RecommendedFoods(),
          SizedBox(height: 20),
          MealsSection(),
        ],
      ),
    );
  }
}