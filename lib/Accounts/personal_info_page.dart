import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  UserData? _userData;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      _userData = await UserDataService.loadUserData();

      if (_userData != null) {
        _nameController.text = _userData!.name ?? '';
        _bioController.text = _userData!.bio ?? '';
      }

      if (_currentUser != null) {
        _emailController.text = _currentUser!.email ?? '';
      }
    } catch (e) {
      _showError('Failed to load user information');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserInfo() async {
    if (_isSaving) return;

    // Validate name
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await UserDataService.updateUserData(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (success) {
        _showSuccess('Personal information updated successfully!');
        // Reload data to confirm
        await _loadUserData();
      } else {
        _showError('Failed to update information. Please try again.');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
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
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- Input fields ---
                  _buildTextField(
                    label: "Full Name",
                    controller: _nameController,
                    icon: Icons.person_outline,
                    readOnly: false,
                  ),
                  const SizedBox(height: 16),

                  _buildTextFieldNoBio(
                    label: "Bio",
                    controller: _bioController,
                    readOnly: false,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: "Email",
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    readOnly: true,
                    hint: "Email cannot be changed",
                  ),
                  const SizedBox(height: 16),

                  // Display other user info (read-only)
                  if (_userData != null) ...[
                    _buildInfoCard(
                      "Gender",
                      _userData!.gender ?? "Not set",
                      Icons.wc,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      "Age",
                      _userData!.age != null ? "${_userData!.age} years" : "Not set",
                      Icons.cake_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      "Weight",
                      _userData!.weight != null ? "${_userData!.weight} kg" : "Not set",
                      Icons.monitor_weight_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      "Height",
                      _userData!.height != null ? "${_userData!.height} cm" : "Not set",
                      Icons.height_outlined,
                    ),
                  ],

                  const SizedBox(height: 40),

                  // --- Save Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveUserInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getInitials() {
    if (_nameController.text.trim().isEmpty) {
      return _currentUser?.email?.substring(0, 2).toUpperCase() ?? "U";
    }

    final names = _nameController.text.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return _nameController.text.substring(0, 2).toUpperCase();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 16,
            color: readOnly ? Colors.grey.shade600 : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: readOnly ? Colors.grey.shade400 : AppColors.secondary,
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldNoBio({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 16,
            color: readOnly ? Colors.grey.shade600 : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint ?? "Tell us about yourself...",
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
