// lib/pages/milestone_preview_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/models/food_models.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/services/user_data_service.dart';

class DailyLogData {
  final DateTime date;
  final int totalCalories;
  final int calorieGoal;
  final int caloriesBurned;
  final Map<String, List<FoodEntry>> foodEntriesByMeal;
  final List<Workout> workouts;
  final String? notes;

  DailyLogData({
    required this.date,
    required this.totalCalories,
    required this.calorieGoal,
    required this.caloriesBurned,
    required this.foodEntriesByMeal,
    required this.workouts,
    this.notes,
  });

  String generateTextLog() {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('${DateFormat('MMMM d, yyyy').format(date)}\n');

    // Add notes if available
    if (notes != null && notes!.isNotEmpty) {
      buffer.writeln('${notes}\n');
    }

    // Food section
    bool hasFoodLogs = false;
    List<String> allFoodItems = [];

    for (var entries in foodEntriesByMeal.values) {
      if (entries.isNotEmpty) {
        hasFoodLogs = true;
        for (var entry in entries) {
          allFoodItems.add('${entry.foodName} (${entry.totalCalories.round()} cal)');
        }
      }
    }

    if (hasFoodLogs) {
      buffer.writeln('I ate:');
      for (var item in allFoodItems) {
        buffer.writeln('  • $item');
      }
      buffer.writeln();
    } else {
      buffer.writeln('No meals logged today\n');
    }

    // Workout section
    if (workouts.isNotEmpty) {
      buffer.writeln('I worked out:');

      for (var workout in workouts) {
        if (workout.isCardio) {
          if (workout.durationMinutes != null) {
            buffer.writeln('  • ${workout.exerciseName} (${workout.durationMinutes} min)');
          } else {
            buffer.writeln('  • ${workout.exerciseName}');
          }
        } else {
          if (workout.sets != null && workout.reps != null) {
            buffer.writeln('  • ${workout.exerciseName} (${workout.sets}×${workout.reps})');
          } else {
            buffer.writeln('  • ${workout.exerciseName}');
          }
        }
      }
      buffer.writeln();
    } else {
      buffer.writeln('No workouts logged today\n');
    }

    // Calorie summary
    buffer.writeln('Consumed: $totalCalories cal');

    if (caloriesBurned > 0) {
      buffer.writeln('Burned: $caloriesBurned cal');
      final netCalories = totalCalories - caloriesBurned;
      buffer.writeln('Net: $netCalories cal');
    }

    return buffer.toString().trim();
  }
}

class MilestonePreviewPage extends StatefulWidget {
  final List<Milestone> milestones;
  final int initialIndex;
  final VoidCallback? onMilestonesChanged;
  final String challengeId;

  const MilestonePreviewPage({
    super.key,
    required this.milestones,
    this.initialIndex = 0,
    this.onMilestonesChanged,
    required this.challengeId,
  });

  @override
  State<MilestonePreviewPage> createState() => _MilestonePreviewPageState();
}

class _MilestonePreviewPageState extends State<MilestonePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isSlideshow = false;
  bool _isUpdating = false;
  Duration _slideshowInterval = const Duration(seconds: 2);

  // Daily log data
  Map<String, DailyLogData> _dailyLogs = {};
  bool _isLoadingLogs = false;

  // Expanded state for each milestone
  Map<int, bool> _expandedStates = {};

  // Key to force rebuild of image widget
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadDailyLogs();
  }

  Future<void> _loadDailyLogs() async {
    if (_isLoadingLogs || widget.milestones.isEmpty) return;

    setState(() => _isLoadingLogs = true);

    try {
      final Map<String, DailyLogData> logs = {};

      // Get calorie goal
      int goal = 2000;
      if (widget.challengeId.isNotEmpty) {
        final calculatedGoal = await UserDataService.getDailyCalorieGoal();
        goal = calculatedGoal;
      }

      for (var milestone in widget.milestones) {
        final date = milestone.date;

        // Load food logs
        final foodLogs = await FoodLogService.getFoodLogsForDate(
          date,
          challengeId: widget.challengeId,
        );

        int totalCalories = 0;
        Map<String, List<FoodEntry>> mealEntries = {
          'Breakfast': [],
          'Lunch': [],
          'Dinner': [],
          'Snack': [],
        };

        for (var log in foodLogs) {
          totalCalories += log.totalCalories.round();
          if (mealEntries.containsKey(log.mealType)) {
            mealEntries[log.mealType] = log.entries;
          }
        }

        // Load workouts
        final workouts = await WorkoutServiceV2.getWorkoutsForDate(
          challengeId: widget.challengeId,
          date: date,
        );

        // Calculate calories burned
        int caloriesBurned = 0;
        if (workouts.isNotEmpty) {
          final userData = await UserDataService.loadUserData();
          final userWeight = userData?.weight?.toDouble() ?? 70.0;

          for (var workout in workouts) {
            caloriesBurned += workout.calculateCaloriesBurned(userWeight);
          }
        }

        logs[date.toString()] = DailyLogData(
          date: date,
          totalCalories: totalCalories,
          calorieGoal: goal,
          caloriesBurned: caloriesBurned,
          foodEntriesByMeal: mealEntries,
          workouts: workouts,
          notes: milestone.notes,
        );
      }

      setState(() {
        _dailyLogs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingLogs = false);
      _showSnackBar('Failed to load daily logs');
    }
  }

  @override
  void dispose() {
    _stopSlideshow();
    _pageController.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    if (_isSlideshow) return;
    setState(() => _isSlideshow = true);
    _runSlideshow();
  }

  void _runSlideshow() async {
    while (_isSlideshow && mounted) {
      await Future.delayed(_slideshowInterval);
      if (_isSlideshow && mounted && widget.milestones.isNotEmpty) {
        int nextIndex = (_currentIndex + 1) % widget.milestones.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _stopSlideshow() => setState(() => _isSlideshow = false);

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSlideshowSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Slideshow Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Slide Interval',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                _buildIntervalChip(const Duration(seconds: 1), '1s'),
                _buildIntervalChip(const Duration(seconds: 2), '2s'),
                _buildIntervalChip(const Duration(seconds: 3), '3s'),
                _buildIntervalChip(const Duration(seconds: 5), '5s'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startSlideshow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Slideshow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(Duration duration, String label) {
    bool isSelected = _slideshowInterval == duration;
    return GestureDetector(
      onTap: () {
        setState(() {
          _slideshowInterval = duration;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.secondary : const Color(0xFFE0E0E0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF666666),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final milestones = widget.milestones;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${_currentIndex + 1} of ${milestones.length} · "
              "${DateFormat("MMM d, yyyy").format(milestones[_currentIndex].date)}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSlideshow ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _isSlideshow ? _stopSlideshow : () => _showSlideshowSettings(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              // Change Image option
              PopupMenuItem(
                value: 'change_image',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    const Text(
                      'Change Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete Image option
              const PopupMenuItem(
                value: 'delete_image',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Delete Image',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: ValueKey(_currentIndex), // Force rebuild on index change
              controller: _pageController,
              itemCount: milestones.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                final logData = _dailyLogs[milestone.date.toString()];
                final isExpanded = _expandedStates[index] ?? false;

                return Stack(
                  children: [
                    // Image
                    Center(
                      child: _buildMainImage(milestone),
                    ),

                    // Slideshow indicator
                    if (_isSlideshow)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.slideshow,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_slideshowInterval.inSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Text overlay at the bottom (Facebook style)
                    if (logData != null)
                      Positioned(
                        bottom: 50,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTextLogContent(logData, isExpanded),
                                if (_shouldShowSeeMore(logData.generateTextLog()))
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _expandedStates[index] = !isExpanded;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        isExpanded ? 'See Less' : 'See More',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Thumbnail strip
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return GestureDetector(
                  onTap: () {
                    _pageController.jumpToPage(index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnailWidget(milestone),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainImage(Milestone milestone) {
    // Use unique key based on milestone data to force rebuild
    final imageKey = Key('${milestone.id}_${milestone.updatedAt.millisecondsSinceEpoch}');

    if (milestone.imageUrl != null) {
      return Image.network(
        milestone.imageUrl!,
        key: imageKey,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              color: AppColors.secondary,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image,
            size: 100,
            color: Colors.white54,
          );
        },
      );
    } else if (milestone.imagePath != null) {
      return Image.file(
        File(milestone.imagePath!),
        key: imageKey,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image,
            size: 100,
            color: Colors.white54,
          );
        },
      );
    } else {
      return const Icon(
        Icons.image_not_supported,
        size: 100,
        color: Colors.white54,
      );
    }
  }

  Widget _buildTextLogContent(DailyLogData logData, bool isExpanded) {
    final fullText = logData.generateTextLog();
    final lines = fullText.split('\n');

    // Show first 4 lines if not expanded
    final displayText = isExpanded
        ? fullText
        : lines.take(4).join('\n');

    return Text(
      displayText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.5,
      ),
      maxLines: isExpanded ? null : 4,
      overflow: isExpanded ? null : TextOverflow.ellipsis,
    );
  }

  bool _shouldShowSeeMore(String text) {
    return text.split('\n').length > 4;
  }

  void _handleMenuAction(String action) {
    if (_isUpdating) return;

    switch (action) {
      case 'change_image':
        _changeCurrentImage();
        break;
      case 'delete_image':
        _deleteCurrentImage();
        break;
    }
  }

  void _changeCurrentImage() async {
    if (widget.milestones.isEmpty) return;
    final milestone = widget.milestones[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Choose a new photo for this milestone",
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImageForChange(ImageSource.camera, milestone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImageForChange(ImageSource.gallery, milestone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              color: AppColors.secondary.withOpacity(0.1),
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
                icon,
                size: 32,
                color: AppColors.secondary.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label == 'Camera' ? 'Use camera' : 'Choose photo',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondary.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickImageForChange(ImageSource source, Milestone milestone) async {
    Navigator.pop(context);

    try {
      if (source == ImageSource.camera) {
        // Handle camera permission
        if (Platform.isAndroid) {
          // On Android, explicitly request permission
          var status = await Permission.camera.request();
          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Camera permission denied"),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return;
          }
        } else if (Platform.isIOS) {
          // On iOS, check permission status first
          var status = await Permission.camera.status;
          if (status.isDenied || status.isRestricted) {
            // Request permission - this will show the dialog on iOS
            status = await Permission.camera.request();
            if (!status.isGranted) {
              if (!mounted) return;
              // If permanently denied, offer to open settings
              if (status.isPermanentlyDenied) {
                final shouldOpen = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Permission Required'),
                    content: const Text(
                      'Camera permission is required to take photos. Please enable it in Settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
                if (shouldOpen == true) {
                  await openAppSettings();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Camera permission denied"),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
              return;
            }
          }
          // If permission is already granted or just granted, proceed
        }
      } else if (source == ImageSource.gallery) {
        PermissionStatus status;

        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;

          if (androidInfo.version.sdkInt >= 33) {
            status = await Permission.photos.request();
          } else {
            status = await Permission.storage.request();
          }

          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Photos permission is required to select images"),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return;
          }
        }
        // On iOS, image_picker handles photo library permissions automatically via PHPickerViewController
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        setState(() => _isUpdating = true);

        // Create updated milestone with new image
        final updatedMilestone = milestone.copyWith(
          imagePath: pickedFile.path,
          updatedAt: DateTime.now(),
        );

        final success = await MilestoneService.updateMilestone(
          updatedMilestone,
          challengeId: widget.challengeId,
          newImageFile: File(pickedFile.path),
        );

        if (success && mounted) {
          // Update the milestone in the list
          setState(() {
            widget.milestones[_currentIndex] = updatedMilestone;
          });

          // Clear image cache to ensure new image loads
          if (milestone.imageUrl != null) {
            await NetworkImage(milestone.imageUrl!).evict();
          }

          widget.onMilestonesChanged?.call();
          _showSnackBar('Image updated successfully');
        } else {
          _showSnackBar('Failed to update image. Please try again.');
        }
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _deleteCurrentImage() {
    if (widget.milestones.isEmpty) return;
    final milestone = widget.milestones[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Image',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this milestone image? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _confirmDelete(milestone),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Milestone milestone) async {
    Navigator.pop(context);
    try {
      setState(() => _isUpdating = true);
      final success = await MilestoneService.deleteMilestone(
        milestone.id,
        challengeId: widget.challengeId,
      );

      if (success && mounted) {
        setState(() {
          final index = _currentIndex;
          widget.milestones.removeAt(index);

          if (widget.milestones.isEmpty) {
            Navigator.pop(context);
            return;
          } else if (index >= widget.milestones.length) {
            _currentIndex = widget.milestones.length - 1;
            _pageController.animateToPage(
              _currentIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });

        widget.onMilestonesChanged?.call();
        _showSnackBar('Image deleted successfully');
      } else {
        _showSnackBar('Failed to delete image. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _buildThumbnailWidget(Milestone milestone) {
    final thumbnailKey = Key('thumb_${milestone.id}_${milestone.updatedAt.millisecondsSinceEpoch}');

    if (milestone.imageUrl != null) {
      return Image.network(
        milestone.imageUrl!,
        key: thumbnailKey,
        width: 60,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 60,
            height: 80,
            color: Colors.grey.shade800,
            child: const Icon(Icons.broken_image, color: Colors.white54),
          );
        },
      );
    } else if (milestone.imagePath != null) {
      return Image.file(
        File(milestone.imagePath!),
        key: thumbnailKey,
        width: 60,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 60,
            height: 80,
            color: Colors.grey.shade800,
            child: const Icon(Icons.broken_image, color: Colors.white54),
          );
        },
      );
    } else {
      return Container(
        width: 60,
        height: 80,
        color: Colors.grey.shade800,
        child: const Icon(Icons.image_not_supported, color: Colors.white54),
      );
    }
  }
}