import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class GenderSelection extends StatefulWidget {
  const GenderSelection({super.key});

  @override
  State<GenderSelection> createState() => _GenderSelectionState();
}

class _GenderSelectionState extends State<GenderSelection> {
  String selectedGender = "Female"; // Default selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Gender",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Select your gender.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Male Button
            genderOption(
              title: "Male",
              icon: Icons.male,
              color: Colors.blue.shade600,
              isSelected: selectedGender == "Male",
              onTap: () {
                setState(() {
                  selectedGender = "Male";
                });
              },
            ),
            const SizedBox(height: 25),

            // Female Button
            genderOption(
              title: "Female",
              icon: Icons.female,
              color: Colors.pink.shade400,
              isSelected: selectedGender == "Female",
              onTap: () {
                setState(() {
                  selectedGender = "Female";
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget genderOption({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color,
              child: Icon(icon, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
