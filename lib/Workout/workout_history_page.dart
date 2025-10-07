import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/workout_model.dart';
import 'package:capstone_project/services/workout_service.dart';

class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkoutService workoutService = WorkoutService();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Workout History',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<WorkoutModel>>(
        stream: workoutService.getWorkoutHistory(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final workouts = snapshot.data ?? [];

          if (workouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No workout history',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Group workouts by date
          Map<String, List<WorkoutModel>> groupedWorkouts = {};
          for (var workout in workouts) {
            String dateKey = DateFormat('yyyy-MM-dd').format(workout.date);
            if (!groupedWorkouts.containsKey(dateKey)) {
              groupedWorkouts[dateKey] = [];
            }
            groupedWorkouts[dateKey]!.add(workout);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedWorkouts.length,
            itemBuilder: (context, index) {
              String dateKey = groupedWorkouts.keys.elementAt(index);
              List<WorkoutModel> dayWorkouts = groupedWorkouts[dateKey]!;
              DateTime date = DateTime.parse(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ...dayWorkouts.map((workout) => _buildHistoryCard(workout)),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(date.year, date.month, date.day);

    if (workoutDate == today) {
      return 'Today';
    } else if (workoutDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }

  Widget _buildHistoryCard(WorkoutModel workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: workout.completedSetCount == workout.sets
                    ? Colors.green.withOpacity(0.1)
                    : AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                workout.completedSetCount == workout.sets
                    ? Icons.check_circle
                    : Icons.fitness_center,
                color: workout.completedSetCount == workout.sets
                    ? Colors.green
                    : AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.exerciseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${workout.sets} sets × ${workout.reps} reps • ${workout.duration} min',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${workout.completedSetCount}/${workout.sets}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(workout.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}