import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class FitCheckLoader extends StatelessWidget {
  final bool fullscreen;

  const FitCheckLoader({super.key, this.fullscreen = false});

  @override
  Widget build(BuildContext context) {
    final animation = Lottie.asset(
      'assets/animations/runningcharacter.json',
      width: fullscreen ? 100 : 80, // larger size in fullscreen
      height: fullscreen ? 100 : 80,
      fit: BoxFit.contain,
      repeat: true,
      animate: true,
    );
    // if fullscreen, wrap in Scaffold + Center
    if (fullscreen) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: animation),
      );
    }

    // if not fullscreen, return only animation widget
    return animation;
  }
}
