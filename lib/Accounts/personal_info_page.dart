import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'dart:io';

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
  bool _isUploadingImage = false;
  UserData? _userData;
  User? _currentUser;
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<void> _pickAndUploadImage() async {
    try {
      // Show bottom sheet to choose camera or gallery (NO delete option here)
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose Profile Picture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.photo_camera, color: AppColors.secondary),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: AppColors.secondary),
                    title: const Text('Choose from Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) return; // User cancelled

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // User cancelled

      setState(() => _isUploadingImage = true);

      // Delete old profile picture if it exists
      if (_userData?.profilePictureUrl != null && _userData!.profilePictureUrl!.isNotEmpty) {
        print('Deleting old profile picture...');
        await ImageStorageService.deleteImage(_userData!.profilePictureUrl!);
      }

      // Upload to Firebase Storage
      final File imageFile = File(pickedFile.path);
      final String? downloadUrl = await ImageStorageService.uploadProfileImage(imageFile);

      if (downloadUrl != null) {
        // Update user data with new profile picture URL
        final success = await UserDataService.updateUserData(
          profilePictureUrl: downloadUrl,
        );

        if (success) {
          _showSuccess('Profile picture updated successfully!');
          await _loadUserData();
        } else {
          _showError('Failed to save profile picture URL');
        }
      } else {
        _showError('Failed to upload profile picture');
      }
    } catch (e) {
      _showError('An error occurred while updating profile picture');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    setState(() => _isUploadingImage = true);

    try {
      // Delete the image from Firebase Storage first
      if (_userData?.profilePictureUrl != null && _userData!.profilePictureUrl!.isNotEmpty) {
        print('Deleting profile picture from Storage: ${_userData!.profilePictureUrl}');
        final deleted = await ImageStorageService.deleteImage(_userData!.profilePictureUrl!);
        if (deleted) {
          print('✅ Profile picture deleted from Storage');
        } else {
          print('⚠️ Failed to delete profile picture from Storage');
        }
      }

      // Remove the URL from Firestore
      final success = await UserDataService.updateUserData(
        profilePictureUrl: '',
      );

      if (success) {
        _showSuccess('Profile picture removed');
        await _loadUserData();
      } else {
        _showError('Failed to remove profile picture');
      }
    } catch (e) {
      print('Error removing profile picture: $e');
      _showError('An error occurred');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _viewProfilePicture() {
    if (_userData?.profilePictureUrl == null || _userData!.profilePictureUrl!.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProfilePictureViewer(
          imageUrl: _userData!.profilePictureUrl!,
          onDelete: () async {
            Navigator.pop(context); // Close viewer
            await _removeProfilePicture();
          },
        ),
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
                      GestureDetector(
                        onTap: _viewProfilePicture,
                        child: _isUploadingImage
                            ? Stack(
                                alignment: Alignment.center,
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
                                  const CircularProgressIndicator(),
                                ],
                              )
                            : _userData?.profilePictureUrl != null &&
                                    _userData!.profilePictureUrl!.isNotEmpty
                                ? CircleAvatar(
                                    backgroundColor: AppColors.secondary.shade200,
                                    radius: 60,
                                    child: ClipOval(
                                      child: Image.network(
                                        _userData!.profilePictureUrl!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Text(
                                            _getInitials(),
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
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
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
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

// Full-screen profile picture viewer with delete option
class _ProfilePictureViewer extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDelete;

  const _ProfilePictureViewer({
    required this.imageUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove Profile Picture'),
                  content: const Text('Are you sure you want to remove your profile picture?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        onDelete(); // Call delete function
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white, size: 80),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
