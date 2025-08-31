import 'package:flutter/material.dart';

class PageContentWrapper extends StatelessWidget {
  final Widget child;

  const PageContentWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter, // 👈 Stick to the top
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520, // 👈 keeps it neat on large screens
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,   // 👈 very small top padding (almost at the top)
            bottom: 0,
          ),
          child: child,
        ),
      ),
    );
  }
}
