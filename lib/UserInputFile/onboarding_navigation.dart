import 'package:flutter/material.dart';
import 'onboarding_data.dart';

/// Provides navigation callbacks and data for onboarding pages within the wizard
class OnboardingNavigation extends InheritedWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final OnboardingData data;

  const OnboardingNavigation({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.data,
    required super.child,
  });

  static OnboardingNavigation? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OnboardingNavigation>();
  }

  @override
  bool updateShouldNotify(OnboardingNavigation oldWidget) {
    return onNext != oldWidget.onNext ||
           onBack != oldWidget.onBack ||
           data != oldWidget.data;
  }
}
