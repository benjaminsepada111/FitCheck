import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    this.currentIndex = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, "assets/icons/home.svg"),
              _buildNavItem(1, "assets/icons/food.svg"),
              _buildNavItem(2, "assets/icons/workout.svg"), // Workout at index 2
              _buildNavItem(3, "assets/icons/profile.svg"), // Profile at index 3
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String iconPath) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                iconPath,
                color: isSelected ? AppColors.secondary : Colors.grey.shade600,
                height: 28,
                width: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
