import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/profile.dart';

// Example profile page (replace with your real ProfilePage)

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    this.currentIndex = 0,
    required this.onTap,
  });

  void _handleTap(BuildContext context, int index) {
    if (index == 2) {
      // ✅ Navigate directly to Profile without touching MainPage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else {
      // ✅ Keep normal behavior for Home & Food
      onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _handleTap(context, index),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/home.svg",
            color: currentIndex == 0 ? Colors.green : Colors.grey,
            height: 48,
          ),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/food.svg",
            color: currentIndex == 1 ? Colors.green : Colors.grey,
            height: 48,
          ),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/profile.svg",
            color: currentIndex == 2 ? Colors.green : Colors.grey,
            height: 48,
          ),
          label: "",
        ),
      ],
    );
  }
}
