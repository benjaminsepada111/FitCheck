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

  bool _isTextLogView = false;

  // Daily log data
  Map<String, DailyLogData> _dailyLogs = {};
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSlideshowSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slideshow Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Slide Interval',
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
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
              _isTextLogView ? Icons.image : Icons.notes,
              color: Colors.white,
            ),
            onPressed: () async {
              if (!_isTextLogView && _dailyLogs.isEmpty) {
                await _loadDailyLogs();
              }
              setState(() {
                _isTextLogView = !_isTextLogView;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isSlideshow ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _isTextLogView
                ? null
                : (_isSlideshow ? _stopSlideshow : () => _showSlideshowSettings()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              // Change Image option
              const PopupMenuItem(
                value: 'change_image',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Change Image'),
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
                    Text('Delete Image', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: _isTextLogView ? _buildTextLogView() : Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: milestones.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return Stack(
                  children: [
                    Center(
                      child: milestone.imageUrl != null
                          ? Image.network(
                        milestone.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress
                                  .expectedTotalBytes !=
                                  null
                                  ? loadingProgress
                                  .cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
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
                      )
                          : milestone.imagePath != null
                          ? Image.file(
                        File(milestone.imagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.white54,
                          );
                        },
                      )
                          : const Icon(Icons.image_not_supported,
                          size: 100, color: Colors.white54),
                    ),
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
                    if (milestone.notes != null && milestone.notes!.isNotEmpty)
                      Positioned(
                        bottom: 110,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            milestone.notes!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
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
                      child: _buildImageWidget(milestone),
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () =>
                      _pickImageForChange(ImageSource.camera, milestone),
                ),
                _buildImageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () =>
                      _pickImageForChange(ImageSource.gallery, milestone),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  void _pickImageForChange(ImageSource source, Milestone milestone) async {
    Navigator.pop(context);

    try {
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
              const SnackBar(content: Text("Photos permission is required to select images")),
            );
            return;
          }
        }
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        setState(() => _isUpdating = true);
        final updatedMilestone = milestone.copyWith(
          imagePath: pickedFile.path,
          updatedAt: DateTime.now(),
        );

        final success = await MilestoneService.updateMilestone(
          updatedMilestone,
          challengeId: widget.challengeId,
          newImageFile: File(pickedFile.path),
        );

        if (success) {
          setState(() {
            widget.milestones[_currentIndex] = updatedMilestone;
          });

          widget.onMilestonesChanged?.call();
          _showSnackBar('Image updated successfully');
        } else {
          _showSnackBar('Failed to update image. Please try again.');
        }
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _deleteCurrentImage() {
    if (widget.milestones.isEmpty) return;
    final milestone = widget.milestones[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
            'Are you sure you want to delete this milestone image? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => _confirmDelete(milestone),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Milestone milestone) async {
    Navigator.pop(context);
    try {
      setState(() => _isUpdating = true);
      final success = await MilestoneService.deleteMilestone(milestone.id,
          challengeId: widget.challengeId);
      if (success) {
        setState(() {
          final index = _currentIndex;
          widget.milestones.removeAt(index);

          if (widget.milestones.isEmpty) {
            Navigator.pop(context);
            return;
          } else if (index >= widget.milestones.length) {
            _currentIndex = widget.milestones.length - 1;
            _pageController.animateToPage(_currentIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
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
      setState(() => _isUpdating = false);
    }
  }

  Widget _buildImageWidget(Milestone milestone) {
    if (milestone.imageUrl != null) {
      return Image.network(milestone.imageUrl!,
          width: 60, height: 80, fit: BoxFit.cover);
    } else if (milestone.imagePath != null) {
      return Image.file(File(milestone.imagePath!),
          width: 60, height: 80, fit: BoxFit.cover);
    } else {
      return Container(
          width: 60,
          height: 80,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported));
    }
  }

  Widget _buildTextLogView() {
    if (_isLoadingLogs) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FitCheckLoader(),
            SizedBox(height: 20),
            Text(
              'Loading daily logs...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final milestones = widget.milestones;

    return PageView.builder(
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(milestone.date),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM d, yyyy').format(milestone.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (logData != null) ...[
                  SelectableText(
                    logData.generateTextLog(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No logs available for this day',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: logData != null
                        ? () => _shareTextLog(logData.generateTextLog())
                        : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Log'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareTextLog(String logText) async {
    try {
      await Share.share(
        logText,
        subject: 'My Fitness Log - ${DateFormat('MMM d, yyyy').format(widget.milestones[_currentIndex].date)}',
      );
    } catch (e) {
      _showSnackBar('Failed to share log');
    }
  }
}