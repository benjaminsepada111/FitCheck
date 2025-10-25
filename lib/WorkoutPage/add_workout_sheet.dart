import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/cardio_exercise.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'package:capstone_project/services/workout_cache_service.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/widgets/segmented_toggle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class AddWorkoutSheet extends StatefulWidget {
  final Challenge currentChallenge;
  final Function()? onWorkoutAdded;

  const AddWorkoutSheet({
    super.key,
    required this.currentChallenge,
    this.onWorkoutAdded,
  });

  @override
  State<AddWorkoutSheet> createState() => _AddWorkoutSheetState();
}

class _AddWorkoutSheetState extends State<AddWorkoutSheet> {
  // Workout type toggle: 0 = Cardio, 1 = Strength
  int _selectedWorkoutType = 0;

  // Cardio controllers and state
  final TextEditingController _cardioSearchController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  List<CardioExercise> _searchResults = [];
  CardioExercise? _selectedCardioExercise;
  bool _isSearching = false;
  UserData? _userData;

  // Strength controllers
  final TextEditingController _strengthNameController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  // Common
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _cardioSearchController.dispose();
    _durationController.dispose();
    _strengthNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await UserDataService.loadUserData();
    setState(() {
      _userData = userData;
    });
  }

  Future<void> _searchWorkouts(String query) async {
    if (query.trim().length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _selectedCardioExercise = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await WorkoutCacheService.searchWorkouts(query.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _selectedCardioExercise = null;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectCardioExercise(CardioExercise exercise) {
    setState(() {
      _selectedCardioExercise = exercise;
      _cardioSearchController.text = exercise.name;
      _searchResults = [];
    });
  }

  int _calculateCalories(double met, int durationMinutes) {
    final weight = _userData?.weight?.toDouble() ?? 70.0;
    final hours = durationMinutes / 60.0;
    return (met * weight * hours).round();
  }

  int _calculateCaloriesPer30Min(double met) {
    final weight = _userData?.weight?.toDouble() ?? 70.0;
    return (met * weight * 0.5).round();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    if (_selectedWorkoutType == 0) {
      await _saveCardioWorkout();
    } else {
      await _saveStrengthWorkout();
    }
  }

  Future<void> _saveCardioWorkout() async {
    if (_selectedCardioExercise == null) {
      _showError('Please select a cardio exercise');
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
      _showError('Duration seems too long');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload image if selected
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await ImageStorageService.uploadWorkoutImage(
          _selectedImage!,
          challengeId: widget.currentChallenge.id,
        );
      }

      final workout = Workout(
        id: WorkoutService.generateWorkoutId(),
        userId: user.uid,
        exerciseName: _selectedCardioExercise!.name,
        workoutType: 'cardio',
        durationMinutes: duration,
        met: _selectedCardioExercise!.met,
        imageUrl: uploadedImageUrl,
        timestamp: DateTime.now(),
      );

      final success = await WorkoutService.createWorkout(
        workout,
        widget.currentChallenge.id,
      );

      if (!mounted) return;

      if (success) {
        // Track achievement (with timeout to prevent hanging)
        try {
          await UserAchievementService.trackWorkoutCompletion()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Achievement tracking failed: $e');
          // Don't block the user, continue anyway
        }

        if (widget.onWorkoutAdded != null) {
          widget.onWorkoutAdded!();
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
                const Expanded(child: Text('Cardio workout added successfully!')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        throw Exception('Failed to save workout');
      }
    } catch (e) {
      print('Error saving cardio workout: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Failed to save workout. Please try again.');
    }
  }

  Future<void> _saveStrengthWorkout() async {
    final exerciseName = _strengthNameController.text.trim();
    final setsText = _setsController.text.trim();
    final repsText = _repsController.text.trim();

    if (exerciseName.isEmpty) {
      _showError('Please enter an exercise name');
      return;
    }

    if (exerciseName.length < 2) {
      _showError('Exercise name must be at least 2 characters');
      return;
    }

    if (setsText.isEmpty) {
      _showError('Please enter the number of sets');
      return;
    }

    final sets = int.tryParse(setsText);
    if (sets == null || sets <= 0) {
      _showError('Please enter a valid number of sets greater than 0');
      return;
    }

    if (sets > 100) {
      _showError('Number of sets seems too high');
      return;
    }

    if (repsText.isEmpty) {
      _showError('Please enter the number of reps');
      return;
    }

    final reps = int.tryParse(repsText);
    if (reps == null || reps <= 0) {
      _showError('Please enter a valid number of reps greater than 0');
      return;
    }

    if (reps > 1000) {
      _showError('Number of reps seems too high');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload image if selected
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await ImageStorageService.uploadWorkoutImage(
          _selectedImage!,
          challengeId: widget.currentChallenge.id,
        );
      }

      final workout = Workout(
        id: WorkoutService.generateWorkoutId(),
        userId: user.uid,
        exerciseName: exerciseName,
        workoutType: 'strength',
        sets: sets,
        reps: reps,
        imageUrl: uploadedImageUrl,
        timestamp: DateTime.now(),
      );

      final success = await WorkoutService.createWorkout(
        workout,
        widget.currentChallenge.id,
      );

      if (!mounted) return;

      if (success) {
        // Track achievement (with timeout to prevent hanging)
        try {
          await UserAchievementService.trackWorkoutCompletion()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          print('Achievement tracking failed: $e');
          // Don't block the user, continue anyway
        }

        if (widget.onWorkoutAdded != null) {
          widget.onWorkoutAdded!();
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
                Expanded(child: Text('Added $exerciseName workout')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        throw Exception('Failed to save workout');
      }
    } catch (e) {
      print('Error saving strength workout: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Failed to save workout. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
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
                  icon: const Icon(Icons.close, color: Color(0xFF666666), size: 24),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Workout Type Toggle (Cardio / Strength)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: SegmentedToggle(
              options: const ['Cardio', 'Strength'],
              selectedIndex: _selectedWorkoutType,
              onChanged: (index) {
                setState(() {
                  _selectedWorkoutType = index;
                  // Clear fields when switching
                  _cardioSearchController.clear();
                  _durationController.clear();
                  _strengthNameController.clear();
                  _setsController.clear();
                  _repsController.clear();
                  _selectedCardioExercise = null;
                  _searchResults = [];
                  _selectedImage = null;
                });
              },
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedWorkoutType == 0)
                    _buildCardioForm()
                  else
                    _buildStrengthForm(),

                  const SizedBox(height: 20),
                  _buildImageUploadSection(),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.6),
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
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
                            'Save Workout',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardioForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Exercise
        Text(
          'Search Exercise',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cardioSearchController,
          onChanged: (value) {
            _searchWorkouts(value);
          },
          decoration: InputDecoration(
            hintText: "Type at least 2 characters to search...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: AppColors.secondary),
            suffixIcon: _cardioSearchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade400),
                    onPressed: () {
                      _cardioSearchController.clear();
                      setState(() {
                        _selectedCardioExercise = null;
                        _searchResults = [];
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

        // Search Results
        if (_isSearching) ...[
          const SizedBox(height: 16),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ] else if (_searchResults.isNotEmpty && _selectedCardioExercise == null) ...[
          const SizedBox(height: 16),
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
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final exercise = _searchResults[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    exercise.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '~${_calculateCaloriesPer30Min(exercise.met)} cal/30min',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => _selectCardioExercise(exercise),
                );
              },
            ),
          ),
        ] else if (_cardioSearchController.text.length >= 2 && _searchResults.isEmpty && !_isSearching && _selectedCardioExercise == null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.search_off, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No exercises found. Try different keywords.',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Show suggested workouts when search is empty
        if (_cardioSearchController.text.isEmpty && _selectedCardioExercise == null) ...[
          const SizedBox(height: 16),
          FutureBuilder<List<CardioExercise>>(
            future: WorkoutCacheService.getSuggestedWorkouts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final suggested = snapshot.data!;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withOpacity(0.08),
                      AppColors.secondary.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.2), width: 1.5),
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
                          child: Icon(Icons.star, color: AppColors.secondary, size: 18),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggested.map((workout) {
                        return GestureDetector(
                          onTap: () {
                            _cardioSearchController.text = workout.name.split(',').first.trim();
                            _searchWorkouts(_cardioSearchController.text);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.3),
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
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Selected Exercise Info
        if (_selectedCardioExercise != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_fire_department, color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MET Value',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedCardioExercise!.met}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedCardioExercise!.categoryDisplayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Duration Input
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

          // Calorie Preview
          if (_durationController.text.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final duration = int.tryParse(_durationController.text);
                if (duration == null || duration <= 0) return const SizedBox.shrink();

                final calories = _calculateCalories(_selectedCardioExercise!.met, duration);
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
                    border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.local_fire_department, color: AppColors.secondary, size: 24),
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
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStrengthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise Name
        Text(
          'Exercise Name',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _strengthNameController,
          decoration: InputDecoration(
            hintText: "e.g., Bench Press, Squats, Deadlifts",
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.fitness_center, color: AppColors.secondary),
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

        // Sets and Reps Row
        Row(
          children: [
            // Sets
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sets',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "0",
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
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Reps
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "0",
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
                ],
              ),
            ),
          ],
        ),
      ],
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
        if (_selectedImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
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
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
