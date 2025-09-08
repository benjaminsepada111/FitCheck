import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/home.svg", // 👈 replace with your path
            color: currentIndex == 0 ? Colors.green : Colors.grey,
            height: 48,
          ),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/food.svg", // 👈 replace with your path
            color: currentIndex == 1 ? Colors.green : Colors.grey,
            height: 48,

          ),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/profile.svg", // 👈 replace with your path
            color: currentIndex == 2 ? Colors.green : Colors.grey,
            height: 48,
          ),
          label: "",
        ),
      ],
    );
  }
}
