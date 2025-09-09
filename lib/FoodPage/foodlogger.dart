import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class FoodLogger extends StatelessWidget {
  const FoodLogger({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Food Logger",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary),
            borderRadius: BorderRadius.circular(16),

          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _LoggerItem(label: "Daily Goal", value: "2000"),
                  _LoggerItem(label: "Consumed", value: "1500"),
                  _LoggerItem(label: "Remaining", value: "500"),
                ],
              ),

              const SizedBox(height: 20),

              // Stack with labels + bar
              SizedBox(
                height: 40, // enough height for texts above
                child: Stack(
                  children: [
                    // Progress bar
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: 0.75,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.secondary,
                          ),
                          minHeight: 10,
                        ),
                      ),
                    ),

                    // "Calories" at top-left
                    const Positioned(
                      left: 0,
                      top: 0,
                      child: Text(
                        "Calories",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // "75%" at top-right
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Text(
                        "75%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoggerItem extends StatelessWidget {
  final String label;
  final String value;
  const _LoggerItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}
