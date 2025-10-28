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

      final workouts = await WorkoutService.getChallengeWorkouts(
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

      if (workout.imageUrl != null) {
        await ImageStorageService.deleteImage(workout.imageUrl!);
      }

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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 90),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dayWorkouts = groupedWorkouts[dateKey]!;
        final firstWorkout = dayWorkouts.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header with enhanced styling
            Padding(
              padding: EdgeInsets.only(
                left: 4,
                bottom: 16,
                top: index == 0 ? 0 : 32,
              ),
              child: Row(
                children: [
                  Column(
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
                ],
              ),
            ),
            // Horizontal scrollable workouts for this day
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
      _pageControllers[dateKey] = PageController(viewportFraction: 0.97);
      _currentPages[dateKey] = 0;
    }

    return Column(
      children: [
        // PageView for horizontal swiping
        SizedBox(
          height: 295,
          child: PageView.builder(
            controller: _pageControllers[dateKey],
            itemCount: workouts.length,
            onPageChanged: (page) {
              setState(() {
                _currentPages[dateKey] = page;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildWorkoutCard(workouts[index]),
              );
            },
          ),
        ),
        // Page Indicators
        if (workouts.length > 1) ...[
          const SizedBox(height: 16),
          Row(
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
        ],
      ],
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section with overlay
          Stack(
            children: [
              // Workout Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: workout.imageUrl != null && workout.imageUrl!.isNotEmpty
                    ? Image.network(
                        workout.imageUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade100,
                                ],
                              ),
                            ),
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
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.grey.shade100],
                              ),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              size: 70,
                              color: AppColors.secondary.withOpacity(0.4),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey.shade100],
                          ),
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          size: 70,
                          color: AppColors.secondary.withOpacity(0.5),
                        ),
                      ),
              ),
              // Subtle gradient overlay for text readability
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                  ),
                ),
              ),
              // Type Badge (Top Left) - Enhanced
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: workout.isCardio
                        ? Colors.blue.shade600
                        : AppColors.secondary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (workout.isCardio
                                    ? Colors.blue.shade600
                                    : AppColors.secondary)
                                .withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        workout.isCardio
                            ? Icons.directions_run
                            : Icons.fitness_center,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        workout.isCardio ? 'Cardio' : 'Strength',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Delete Button (Top Right) - Enhanced
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showDeleteConfirmation(workout),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade500.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Exercise Name (Bottom) - Enhanced
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  workout.exerciseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Details Section - Enhanced
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Row with enhanced design
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (workout.isStrength &&
                              workout.sets != null &&
                              workout.reps != null) ...[
                            Icon(
                              Icons.fitness_center,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${workout.sets}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'sets',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${workout.reps}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'reps',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ] else if (workout.isCardio &&
                              workout.durationMinutes != null) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${workout.durationMinutes}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'minutes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(workout.timestamp),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            workout.notes!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
