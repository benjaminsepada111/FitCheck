import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/workout_service.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/WorkoutPage/add_workout_sheet.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';

class WorkoutHistoryPage extends StatefulWidget {
  final Challenge? currentChallenge;

  const WorkoutHistoryPage({
    super.key,
    this.currentChallenge,
  });

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage>
    with AutomaticKeepAliveClientMixin {
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Keep this page alive

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.currentChallenge == null) {
        if (mounted) {
          setState(() {
            _workouts = [];
            _isLoading = false;
          });
        }
        return;
      }

      final workouts = await WorkoutService.getChallengeWorkouts(widget.currentChallenge!.id);
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddWorkoutSheet() {
    if (widget.currentChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please create a challenge first to add workouts'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWorkoutSheet(
        currentChallenge: widget.currentChallenge!,
        onWorkoutAdded: () {
          _loadWorkouts();
        },
      ),
    );
  }

  void _showDeleteConfirmation(Workout workout) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Workout'),
          content: Text(
            'Are you sure you want to delete "${workout.exerciseName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteWorkout(workout);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    try {
      if (widget.currentChallenge == null) {
        throw Exception('No active challenge');
      }

      // Delete image from Cloud Storage if it exists
      if (workout.imageUrl != null) {
        await ImageStorageService.deleteImage(workout.imageUrl!);
      }

      // Create the workout document name to match what's in Firestore
      final sanitized = workout.exerciseName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final timeStamp = workout.timestamp.millisecondsSinceEpoch.toString();
      final workoutDocName = '${sanitized}_$timeStamp';


      final success = await WorkoutService.deleteWorkout(
        workoutDocName,
        widget.currentChallenge!.id,
        workout.timestamp,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Workout deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await _loadWorkouts(); // Reload the list
      } else {
        throw Exception('Failed to delete workout');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete workout'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  String _formatDateGroupKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(date.year, date.month, date.day);

    if (workoutDate == today) {
      return 'Today • ${DateFormat('MMM d, y').format(date)}';
    } else if (workoutDate == yesterday) {
      return 'Yesterday • ${DateFormat('MMM d, y').format(date)}';
    } else {
      return DateFormat('EEEE • MMM d, y').format(date);
    }
  }

  Widget _buildWorkoutImage(Workout workout) {
    // Prefer Cloud Storage URL over legacy base64
    if (workout.imageUrl != null && workout.imageUrl!.isNotEmpty) {
      return SizedBox(
        width: 70,
        height: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            workout.imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 70,
                height: 100,
                color: Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: AppColors.secondary,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 70,
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.broken_image,
                  color: AppColors.secondary,
                  size: 28,
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback to default icon
    return Container(
      width: 70,
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.fitness_center,
        color: AppColors.secondary,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title (matching Food Logger style)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              "Workout History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: FitCheckLoader(),
                  )
                : _workouts.isEmpty
                    ? _buildEmptyState()
                    : _buildWorkoutList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkoutSheet,
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center,
                size: 80,
                color: AppColors.secondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Workout History Empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your workouts to see your progress here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutList() {
    // Group workouts by date
    Map<String, List<Workout>> groupedWorkouts = {};
    for (var workout in _workouts) {
      final dateKey = _formatDateGroupKey(workout.timestamp);
      if (!groupedWorkouts.containsKey(dateKey)) {
        groupedWorkouts[dateKey] = [];
      }
      groupedWorkouts[dateKey]!.add(workout);
    }

    // Get sorted list of dates
    final sortedDates = groupedWorkouts.keys.toList()
      ..sort((a, b) {
        final dateA = groupedWorkouts[a]!.first.timestamp;
        final dateB = groupedWorkouts[b]!.first.timestamp;
        return dateB.compareTo(dateA);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dayWorkouts = groupedWorkouts[dateKey]!;
        final firstWorkout = dayWorkouts.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12, top: index == 0 ? 0 : 8),
              child: Text(
                _formatDateHeader(firstWorkout.timestamp),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            // Workouts for this day
            ...dayWorkouts.map((workout) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading Icon or Image
                    _buildWorkoutImage(workout),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.exerciseName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Workout Type Badge (Cardio or Strength)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: workout.isCardio
                                      ? Colors.blue.withOpacity(0.15)
                                      : Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        workout.isCardio ? Icons.directions_run : Icons.fitness_center,
                                        size: 14,
                                        color: workout.isCardio ? Colors.blue.shade700 : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        workout.isCardio ? 'Cardio' : 'Strength',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: workout.isCardio ? Colors.blue.shade700 : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Show details based on type
                                if (workout.isStrength && workout.sets != null && workout.reps != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${workout.sets} × ${workout.reps}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ] else if (workout.isCardio && workout.durationMinutes != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${workout.durationMinutes} min',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                workout.notes!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(workout.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // Delete button
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(workout),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red.shade400,
                      iconSize: 28,
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}
