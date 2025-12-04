import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/utils/responsive_utils.dart';

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
    final r = context.responsive;
    final isIOS = Platform.isIOS;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: r.size(10),
            offset: Offset(0, r.size(-2)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: isIOS ? r.size(55) : r.size(60),
          padding: r.paddingSymmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(context, 0, "assets/icons/home.svg"),
              _buildNavItem(context, 1, "assets/icons/food.svg"),
              _buildNavItem(context, 2, "assets/icons/dumbbell.svg"),
              _buildNavItem(context, 3, "assets/icons/profile.svg"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String iconPath) {
    final r = context.responsive;
    final isIOS = Platform.isIOS;
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        constraints: BoxConstraints(
          minWidth: r.tapTarget(44),
          minHeight: r.tapTarget(44),
        ),
        padding: isIOS 
          ? r.paddingSymmetric(horizontal: 16, vertical: 0)
          : r.paddingSymmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: isIOS ? r.padding(all: 6) : r.padding(all: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(r.size(10)),
          ),
          child: SvgPicture.asset(
            iconPath,
            colorFilter: ColorFilter.mode(
              isSelected ? AppColors.secondary : Colors.grey.shade600,
              BlendMode.srcIn,
            ),
            height: isIOS ? r.size(30) : r.size(28),
            width: isIOS ? r.size(30) : r.size(28),
          ),
        ),
      ),
    );
  }
}
