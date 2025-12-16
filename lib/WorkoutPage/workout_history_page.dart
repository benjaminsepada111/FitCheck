import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/workout.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/workout_service_v2.dart';
import 'package:capstone_project/services/image_storage_service.dart';
import 'package:capstone_project/WorkoutPage/add_workout_sheet.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';

class WorkoutHistoryPage extends StatefulWidget {
  final Challenge? currentChallenge;

  const WorkoutHistoryPage({super.key, this.currentChallenge});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage>
    with AutomaticKeepAliveClientMixin {
  List<Workout> _workouts = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _lastLoadedChallengeId;

  // Page controllers for each day group
  final Map<String, PageController> _pageControllers = {};
  final Map<String, int> _currentPages = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void dispose() {
    // Dispose all page controllers
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(WorkoutHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChallenge?.id != widget.currentChallenge?.id) {
      _hasLoadedOnce = false;
      _loadWorkouts();
    }
  }

  Future<void> _loadWorkouts({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _hasLoadedOnce &&
        _lastLoadedChallengeId == widget.currentChallenge?.id) {
      return;
    }

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

      final workouts = await WorkoutServiceV2.getChallengeWorkouts(
        widget.currentChallenge!.id,
      );
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
          _hasLoadedOnce = true;
          _lastLoadedChallengeId = widget.currentChallenge?.id;
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
          content: const Text(
            'Please create a challenge first to add workouts',
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
        selectedDate: DateTime.now(),
        onWorkoutAdded: () {
          _loadWorkouts(forceRefresh: true);
        },
      ),
    );
  }

  void _showDeleteConfirmation(Workout workout) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Workout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${workout.exerciseName}"?',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteWorkout(workout);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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

      if (workout.imageUrl != null) {
        await ImageStorageService.deleteImage(workout.imageUrl!);
      }

      final success = await WorkoutServiceV2.deleteWorkout(
        challengeId: widget.currentChallenge!.id,
        workoutId: workout.id,
        workoutDate: workout.timestamp,
        isCardio: workout.isCardio,
        dailyGoal: widget.currentChallenge!.dailyCalorieGoal,
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
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        await _loadWorkouts(forceRefresh: true);
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
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: FitCheckLoader())
          : _workouts.isEmpty
          ? _buildEmptyState()
          : _buildWorkoutList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkoutSheet,
        backgroundColor: AppColors.secondary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white, size: 24),
        label: const Text(
          'Add Workout',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.fitness_center,
                size: 80,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No Workouts Yet',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start your fitness journey today!\nTap the button below to add your first workout',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutList() {
    Map<String, List<Workout>> groupedWorkouts = {};
    for (var workout in _workouts) {
      final dateKey = _formatDateGroupKey(workout.timestamp);
      if (!groupedWorkouts.containsKey(dateKey)) {
        groupedWorkouts[dateKey] = [];
      }
      groupedWorkouts[dateKey]!.add(workout);
    }

    final sortedDates = groupedWorkouts.keys.toList()
      ..sort((a, b) {
        final dateA = groupedWorkouts[a]!.first.timestamp;
        final dateB = groupedWorkouts[b]!.first.timestamp;
        return dateB.compareTo(dateA);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 90),
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
              padding: EdgeInsets.only(
                left: 0,
                right: 16,
                bottom: 16,
                top: index == 0 ? 0 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateHeader(firstWorkout.timestamp),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dayWorkouts.length} ${dayWorkouts.length == 1 ? 'workout' : 'workouts'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Horizontal scrollable workouts
            _buildHorizontalWorkoutSection(dateKey, dayWorkouts),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalWorkoutSection(
      String dateKey,
      List<Workout> workouts,
      ) {
    // Initialize page controller and current page for this day if not exists
    if (!_pageControllers.containsKey(dateKey)) {
      _pageControllers[dateKey] = PageController(viewportFraction: 0.92);
      _currentPages[dateKey] = 0;
    }

    return Column(
      children: [
        // PageView for horizontal swiping
        SizedBox(
          height: 261,
          child: PageView.builder(
            controller: _pageControllers[dateKey],
            itemCount: workouts.length,
            padEnds: false,
            onPageChanged: (page) {
              setState(() {
                _currentPages[dateKey] = page;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildWorkoutCard(workouts[index]),
              );
            },
          ),
        ),
        // Page Indicators
        if (workouts.length > 1) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                workouts.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPages[dateKey] == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPages[dateKey] == index
                        ? AppColors.secondary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF06111D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: workout.imageUrl != null && workout.imageUrl!.isNotEmpty
                    ? Image.network(
                  workout.imageUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 180,
                      color: const Color(0xFF1A2332),
                      child: Center(
                        child: CircularProgressIndicator(
                          value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 3,
                          color: AppColors.secondary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 180,
                      color: const Color(0xFF1A2332),
                      child: Icon(
                        Icons.fitness_center,
                        size: 60,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                )
                    : Container(
                  width: double.infinity,
                  height: 180,
                  color: const Color(0xFF1A2332),
                  child: Icon(
                    Icons.fitness_center,
                    size: 60,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              // Delete button
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showDeleteConfirmation(workout),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type and Time Row with duration/sets inline
                Row(
                  children: [
                    Icon(
                      workout.isCardio
                          ? Icons.directions_run
                          : Icons.fitness_center,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(workout.timestamp),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '|',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      workout.isCardio ? 'Cardio' : 'Strength',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Add duration for cardio or sets/reps for strength inline
                    if (workout.isCardio && workout.durationMinutes != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${workout.durationMinutes} minutes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (workout.isStrength &&
                        workout.sets != null &&
                        workout.reps != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${workout.sets} sets • ${workout.reps} reps',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Exercise Name
                Text(
                  workout.exerciseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}