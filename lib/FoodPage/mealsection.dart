import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 import SVG package
import 'add_food_sheet.dart';

class MealsSection extends StatelessWidget {
  const MealsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> meals = [
      {"name": "Snack", "calories": "320 calories", "icon": "assets/icons/snack.svg"},
      {"name": "Breakfast", "calories": "320 calories", "icon": "assets/icons/breakfast.svg"},
      {"name": "Lunch", "calories": "320 calories", "icon": "assets/icons/lunch.svg"},
      {"name": "Dinner", "calories": "320 calories", "icon": "assets/icons/dinner.svg"},
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
          iconPath: meal["icon"] as String,
        )),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final String name;
  final String calories;
  final String iconPath;

  const _MealCard({
    required this.name,
    required this.calories,
    required this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: SvgPicture.asset(
            iconPath,
            width: 28,
            height: 28,
            color: Colors.black87, // 👈 remove if you want original colors
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            calories,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                thickness: 1,
                height: 1,
                color: Colors.black26,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  OutlinedButton(
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
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add $name",
                          style: const TextStyle(color: Colors.black),
                        ),
                        const Icon(Icons.add, color: Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No foods logged yet",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
