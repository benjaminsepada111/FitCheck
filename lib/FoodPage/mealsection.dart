import 'package:flutter/material.dart';
import 'add_food_sheet.dart';
class MealsSection extends StatelessWidget {
  const MealsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> meals = [
      {"name": "Snack", "calories": "320 calories", "icon": Icons.fastfood},
      {"name": "Breakfast", "calories": "320 calories", "icon": Icons.free_breakfast},
      {"name": "Lunch", "calories": "320 calories", "icon": Icons.lunch_dining},
      {"name": "Dinner", "calories": "320 calories", "icon": Icons.dinner_dining},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Meals",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...meals.map((meal) => _MealCard(
          name: meal["name"] as String,
          calories: meal["calories"] as String,
          icon: meal["icon"] as IconData,
        )),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final String name;
  final String calories;
  final IconData icon;

  const _MealCard({
    required this.name,
    required this.calories,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32, color: Colors.black87),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(calories),
        trailing: const Icon(Icons.keyboard_arrow_down),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Add Meal Button
                OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddFoodSheet(mealName: name),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text("Add $name"),
                ),

                const SizedBox(height: 12),

                // Placeholder text if no foods logged
                const Text(
                  "No foods logged yet",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
              ],
            ),
          )
        ],
      ),
    );
  }
}
