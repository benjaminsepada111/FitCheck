import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AddMilestoneSheet extends StatefulWidget {
  final Function(Milestone milestone, File? imageFile) onSave;

  const AddMilestoneSheet({super.key, required this.onSave});

  @override
  State<AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<AddMilestoneSheet> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission denied")),
        );
        return;
      }
    } else if (source == ImageSource.gallery) {
      // ⭐ REQUEST PHOTO PERMISSION FOR GALLERY
      PermissionStatus status;

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+ - Use photos permission
          status = await Permission.photos.request();
        } else {
          // Android 12 and below - Use storage permission
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Photos permission is required to select images")),
          );
          return;
        }
      }
    }

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _saveMilestone() async {
    if (_selectedImage == null) return;
    if (_isSaving) return; // Prevent double-tap

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      // Normalize date to midnight to avoid duplicate issues
      final normalizedDate = DateTime(now.year, now.month, now.day);

      final milestone = Milestone(
        id: MilestoneService.createDateBasedId(normalizedDate),
        date: normalizedDate,
        imagePath: _selectedImage!.path,
        notes: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      // Track photo upload for achievements
      try {
        await UserAchievementService.trackPhotoUpload();
      } catch (e) {
        // Don't block the success flow if achievement tracking fails
      }

      widget.onSave(milestone, _selectedImage);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save milestone. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Add Milestone Image",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_selectedImage == null) ...[
            const Text(
              "Capture your fitness journey with a progress photo!",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // --- Buttons (Take Photo & Upload) ---
            Row(
              children: [
                // --- Take Photo ---
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.secondary.shade200,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: AppColors.secondary.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Take Photo",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Use camera",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // --- Upload from Gallery ---
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.secondary.shade200,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_library,
                              size: 32,
                              color: AppColors.secondary.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Gallery",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Choose photo",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // --- Preview Selected Image ---
            // --- Preview Selected Image ---
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Selected Image
                    Positioned.fill(
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),

                    // Gradient overlay (for text readability)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Label bottom-left
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Today", // 👈 you can make this dynamic (Today / Yesterday)
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Note/Description ---
            const Text(
              "Note/Description",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Describe your progress",
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.secondary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // --- Buttons Row ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _selectedImage = null; // reset
                              _noteController.clear();
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMilestone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            "Save Milestone",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
