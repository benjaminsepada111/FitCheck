import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Personal Info",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            // --- Profile Picture with Edit button ---
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                 CircleAvatar(
                  backgroundColor: AppColors.secondary.shade200,
                  radius: 60,
                  backgroundImage: AssetImage("assets/profile.jpg"), // 👈 replace with user image
                ),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    // TODO: implement image picker
                  },
                  backgroundColor: AppColors.secondary,
                  child: const Icon(Icons.edit, size: 18, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- Input fields ---
            _buildTextField("Full Name", "Benjamin Sepada III"),
            const SizedBox(height: 16),
            _buildTextField("Nickname", "Jammin"),
            const SizedBox(height: 16),
            _buildTextField("Email", "benjaminlll.sepada@gmail.com"),
            const SizedBox(height: 16),
            _buildTextField("Phone Number", "+63 994 2930 598"),

            const SizedBox(height: 40),

            // --- Save Button ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: save user info
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                   color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable input field ---
  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          readOnly: true, // 👈 make editable if needed
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
