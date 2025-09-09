import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class Slide1 extends StatelessWidget {
  const Slide1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SafeArea(
        child: SingleChildScrollView( // 👈 makes it scrollable if overflow
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Title
              const Text(
                "Profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Enter your height in cm.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // Profile Image Placeholder with edit button
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.shade100,
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Full Name Label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "FULL NAME",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Full Name Input
              TextField(
                decoration: InputDecoration(
                  hintText: "Name",
                  filled: true,
                  fillColor: AppColors.secondary.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bio Label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "BIO",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Bio Input
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "FitCheck",
                  filled: true,
                  fillColor: AppColors.secondary.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 30), // 👈 Added extra space at bottom
            ],
          ),
        ),
      ),
    );
  }
}
