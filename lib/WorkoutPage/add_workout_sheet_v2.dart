import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/cardio_exercise.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:capstone_project/services/workout_cache_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:image_picker/image_picker.dart';

class AddWorkoutSheetV2 extends StatefulWidget {
  final String? challengeId;
  final Function(
    String workoutName,
    int calories, {
    int? durationMinutes,
    double? met,
    String? imageUrl,
  })?
  onWorkoutAdded;

  const AddWorkoutSheetV2({super.key, this.challengeId, this.onWorkoutAdded});

  @override
  State<AddWorkoutSheetV2> createState() => _AddWorkoutSheetV2State();
}

class _AddWorkoutSheetV2State extends State<AddWorkoutSheetV2> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _manualWorkoutController =
      TextEditingController();
  final TextEditingController _manualCaloriesController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<CardioExercise> _searchResults = [];
  CardioExercise? _selectedWorkout;
  bool _isLoading = false;
  bool _isManualEntry = false;
  String? _errorMessage;
  File? _selectedImage;
  bool _isSaving = false;
  UserData? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _durationController.dispose();
    _manualWorkoutController.dispose();
    _manualCaloriesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await UserDataService.loadUserData();
    setState(() {
      _userData = userData;
    });
  }

  Future<void> _searchWorkouts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedWorkout = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await WorkoutCacheService.searchWorkouts(query.trim());

      if (results.isEmpty) {
        setState(() {
          _searchResults = [];
          _selectedWorkout = null;
          _isLoading = false;
          _errorMessage =
              'No workouts found for "$query". Try a different search term.';
        });
      } else {
        setState(() {
          _searchResults = results;
          _selectedWorkout = null;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to search workouts. Please try again.';
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _selectWorkout(CardioExercise workout) {
    setState(() {
      _selectedWorkout = workout;
      _searchController.text = workout.name;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
        });
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _toggleEntryMode() {
    setState(() {
      _isManualEntry = !_isManualEntry;
      _selectedWorkout = null;
      _searchResults = [];
      _searchController.clear();
      _durationController.clear();
      _manualWorkoutController.clear();
      _manualCaloriesController.clear();
      _errorMessage = null;
      _selectedImage = null;
    });
  }

  void _saveWorkout() {
    if (_isManualEntry) {
      _saveManualWorkout();
    } else {
      _saveSelectedWorkout();
    }
  }

  void _saveSelectedWorkout() async {
    if (_selectedWorkout == null) {
      _showError('Please select a workout first');
      return;
    }

    final durationText = _durationController.text.trim();
    if (durationText.isEmpty) {
      _showError('Please enter workout duration');
      return;
    }

    final duration = int.tryParse(durationText);
    if (duration == null || duration <= 0) {
      _showError('Please enter a valid duration greater than 0');
      return;
    }

    if (duration > 600) {
      _showError('Duration seems too long. Please enter a reasonable amount.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image to Cloud Storage if selected
      String? uploadedImageUrl;
      if (_selectedImage != null && widget.challengeId != null) {
        uploadedImageUrl = await ImageStorageService.uploadWorkoutImage(
          _selectedImage!,
          challengeId: widget.challengeId!,
        );

        if (uploadedImageUrl == null) {
          _showError(
            'Failed to upload image. Workout will be saved without photo.',
          );
        }
      } else if (_selectedImage != null && widget.challengeId == null) {
        _showError('Cannot upload image without an active challenge.');
      }

      final calories = _calculateCaloriesForDuration(
        _selectedWorkout!.met,
        duration,
      );
      final workoutName = _selectedWorkout!.name;

      // Track workout for achievements
      try {
        await UserAchievementService.trackWorkoutCompletion();
      } catch (e) {
        // Don't block the success flow
      }

      if (widget.onWorkoutAdded != null) {
        widget.onWorkoutAdded!(
          workoutName,
          calories,
          durationMinutes: duration,
          met: _selectedWorkout!.met,
          imageUrl: uploadedImageUrl,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Added $duration min $workoutName workout')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to add workout. Please try again.');
    }
  }

  void _saveManualWorkout() async {
    final workoutName = _manualWorkoutController.text.trim();
    final caloriesText = _manualCaloriesController.text.trim();

    if (workoutName.isEmpty) {
      _showError('Please enter a workout name');
      return;
    }

    if (workoutName.length < 2) {
      _showError('Workout name must be at least 2 characters');
      return;
    }

    if (caloriesText.isEmpty) {
      _showError('Please enter the calories burned');
      return;
    }

    final calories = int.tryParse(caloriesText);
    if (calories == null || calories <= 0) {
      _showError('Please enter valid calories greater than 0');
      return;
    }

    if (calories > 5000) {
      _showError('Calories seem too high. Please enter a reasonable amount.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image to Cloud Storage if selected
      String? uploadedImageUrl;
      if (_selectedImage != null && widget.challengeId != null) {
        uploadedImageUrl = await ImageStorageService.uploadWorkoutImage(
          _selectedImage!,
          challengeId: widget.challengeId!,
        );

        if (uploadedImageUrl == null) {
          _showError(
            'Failed to upload image. Workout will be saved without photo.',
          );
        }
      } else if (_selectedImage != null && widget.challengeId == null) {
        _showError('Cannot upload image without an active challenge.');
      }

      // Track workout for achievements
      try {
        await UserAchievementService.trackWorkoutCompletion();
      } catch (e) {
        // Don't block the success flow
      }

      if (widget.onWorkoutAdded != null) {
        widget.onWorkoutAdded!(
          workoutName,
          calories,
          imageUrl: uploadedImageUrl,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Added $workoutName workout')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to add workout. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Calculate calories burned for given duration
  /// Formula: Calories = MET × weight(kg) × time(hours)
  int _calculateCaloriesForDuration(double met, int durationMinutes) {
    final weight = _userData?.weight?.toDouble() ?? 70.0; // Default to 70kg
    final hours = durationMinutes / 60.0;
    return (met * weight * hours).round();
  }

  /// Calculate calories per 30 minutes for display
  int _calculateCaloriesPer30Min(double met) {
    final weight = _userData?.weight?.toDouble() ?? 70.0;
    return (met * weight * 0.5).round(); // 0.5 hours = 30 minutes
  }

  Widget _buildCaloriePreview() {
    if (_selectedWorkout == null || _durationController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) return const SizedBox.shrink();

    final calories = _calculateCaloriesForDuration(
      _selectedWorkout!.met,
      duration,
    );

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calories Burned',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$calories cal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$duration min',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Add Workout",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Modern Toggle Buttons
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isManualEntry ? _toggleEntryMode : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isManualEntry
                              ? AppColors.secondary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isManualEntry
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 18,
                              color: !_isManualEntry
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search Workouts',
                              style: TextStyle(
                                color: !_isManualEntry
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: !_isManualEntry ? _toggleEntryMode : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isManualEntry
                              ? AppColors.secondary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isManualEntry
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _isManualEntry
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Entry',
                              style: TextStyle(
                                color: _isManualEntry
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isManualEntry
                  ? _buildManualEntry()
                  : _buildWorkoutSearch(),
            ),

            const SizedBox(height: 16),

            // Enhanced Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppColors.secondary.withOpacity(
                        0.6,
                      ),
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
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
                            'Add Workout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutSearch() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.length > 2) {
                _searchWorkouts(value);
              } else if (value.length <= 2) {
                setState(() {
                  _searchResults = [];
                  _selectedWorkout = null;
                  _errorMessage = null;
                });
              }
            },
            onSubmitted: (value) {
              if (value.length > 2) {
                _searchWorkouts(value);
              }
            },
            decoration: InputDecoration(
              hintText: "Search workouts (e.g., running, yoga)...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: AppColors.secondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade400),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _selectedWorkout = null;
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 32),
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Search Results
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '${_searchResults.length} workouts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final workout = _searchResults[index];
                  final isSelected = _selectedWorkout?.code == workout.code;
                  return Container(
                    color: isSelected
                        ? AppColors.secondary.withOpacity(0.08)
                        : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        workout.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '~${_calculateCaloriesPer30Min(workout.met)} cal/30min',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
                      onTap: () => _selectWorkout(workout),
                    ),
                  );
                },
              ),
            ),
          ] else if (_searchController.text.isEmpty && !_isLoading) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<CardioExercise>>(
              future: WorkoutCacheService.getSuggestedWorkouts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final suggested = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.08),
                        AppColors.secondary.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Popular Workouts',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggested
                            .map(
                              (workout) => GestureDetector(
                                onTap: () {
                                  _searchController.text = workout.name
                                      .split(',')
                                      .first
                                      .trim();
                                  _searchWorkouts(_searchController.text);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.secondary.withOpacity(
                                        0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    workout.name.split(',').first.trim(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (_selectedWorkout != null) ...[
            const SizedBox(height: 24),
            Text(
              'Duration (minutes)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Enter duration in minutes",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                suffixText: 'min',
                suffixStyle: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.secondary, width: 2),
                ),
              ),
            ),
            _buildCaloriePreview(),
          ],

          // Image Upload Section
          const SizedBox(height: 24),
          _buildImageUploadSection(),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Photo (Optional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),

        if (_selectedImage == null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                      color: AppColors.secondary.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                      color: AppColors.secondary.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Name',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualWorkoutController,
            decoration: InputDecoration(
              hintText: "Enter workout name",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Calories Burned',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualCaloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Enter calories burned",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              suffixText: 'cal',
              suffixStyle: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildImageUploadSection(),
        ],
      ),
    );
  }
}
