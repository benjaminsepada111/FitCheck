// examples/achievements_page_with_time_tracking.dart
//
// This is an EXAMPLE showing how to integrate the time tracking system
// with your existing achievements_page.dart
//
// You can copy relevant parts to your actual achievements_page.dart

import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/app_text_styles.dart';
import 'package:capstone_project/services/statistics_service.dart';
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/services/achievement_time_service.dart';

class AchievementsPageWithTimeTracking extends StatefulWidget {
  const AchievementsPageWithTimeTracking({super.key});

  @override
  State<AchievementsPageWithTimeTracking> createState() =>
      _AchievementsPageWithTimeTrackingState();
}

class _AchievementsPageWithTimeTrackingState
    extends State<AchievementsPageWithTimeTracking> {
  bool _isLoading = true;
  Map<String, int> _statistics = {
    'totalCalories': 0,
    'loginDays': 0,
    'workoutsLogged': 0,
    'mealsLogged': 0,
  };
  Map<String, dynamic> _timeMetrics = {
    'daysPassed': 0,
    'weekNumber': 0,
    'monthsPassed': 0,
    'dayOfWeek': 0,
    'isInitialized': false,
  };
  Map<String, AchievementStatus> _achievementStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // Load all data in parallel for better performance
      final results = await Future.wait([
        StatisticsService.getAllStatistics(),
        UserTimeTracker.getAllTimeMetrics(),
        AchievementTimeService.checkAllAchievements(),
      ]);

      if (mounted) {
        setState(() {
          _statistics = results[0] as Map<String, int>;
          _timeMetrics = results[1];
          _achievementStatuses = results[2] as Map<String, AchievementStatus>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          'Achievements & Stats',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Journey Progress Section (NEW!)
                    _buildJourneyProgress(),
                    const SizedBox(height: 24),

                    // Statistics Section
                    const Text(
                      'Your Statistics',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 16),
                    _buildStatisticsGrid(),
                    const SizedBox(height: 24),

                    // Achievements Section
                    const Text(
                      'Achievements',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 16),
                    _buildAchievementsList(),
                  ],
                ),
              ),
            ),
    );
  }

  // NEW: Journey Progress Widget
  Widget _buildJourneyProgress() {
    if (!_timeMetrics['isInitialized']) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Start your journey to unlock achievements!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await UserTimeTracker.initializeUserStartDate();
                  _loadAllData();
                },
                child: const Text('Begin Journey'),
              ),
            ],
          ),
        ),
      );
    }

    final days = _timeMetrics['daysPassed'] ?? 0;
    final week = _timeMetrics['weekNumber'] ?? 0;
    final months = _timeMetrics['monthsPassed'] ?? 0;
    final dayOfWeek = _timeMetrics['dayOfWeek'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Week $week',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildJourneyStatCard(
                    icon: Icons.calendar_today,
                    value: days.toString(),
                    label: 'Total Days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildJourneyStatCard(
                    icon: Icons.event_available,
                    value: months.toString(),
                    label: 'Months',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Week Progress',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$dayOfWeek/7 days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: dayOfWeek / 7,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: [
        _buildStatCard(
          label: 'Total Calories',
          value: _statistics['totalCalories'].toString(),
        ),
        _buildStatCard(
          label: 'Login Days',
          value: _statistics['loginDays'].toString(),
        ),
        _buildStatCard(
          label: 'Workouts Logged',
          value: _statistics['workoutsLogged'].toString(),
        ),
        _buildStatCard(
          label: 'Meals Logged',
          value: _statistics['mealsLogged'].toString(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList() {
    // Achievement definitions with icons and colors
    final achievements = [
      {
        'id': 'first_step',
        'title': 'First Step',
        'icon': Icons.flag,
        'color': Colors.blue,
      },
      {
        'id': 'week_warrior',
        'title': 'Week Warrior',
        'icon': Icons.calendar_view_week,
        'color': Colors.green,
      },
      {
        'id': 'two_week_champion',
        'title': 'Two Week Champion',
        'icon': Icons.event,
        'color': Colors.teal,
      },
      {
        'id': 'fitness_enthusiast',
        'title': 'Fitness Enthusiast',
        'icon': Icons.fitness_center,
        'color': Colors.orange,
      },
      {
        'id': 'meal_master',
        'title': 'Meal Master',
        'icon': Icons.restaurant_menu,
        'color': Colors.purple,
      },
      {
        'id': 'consistency_king',
        'title': 'Consistency King',
        'icon': Icons.emoji_events,
        'color': Colors.amber,
      },
      {
        'id': 'monthly_milestone',
        'title': 'Monthly Milestone',
        'icon': Icons.celebration,
        'color': Colors.pink,
      },
      {
        'id': 'quarter_master',
        'title': 'Quarter Master',
        'icon': Icons.workspace_premium,
        'color': Colors.deepPurple,
      },
      {
        'id': 'century_club',
        'title': 'Century Club',
        'icon': Icons.military_tech,
        'color': Colors.indigo,
      },
      {
        'id': 'half_year_hero',
        'title': 'Half Year Hero',
        'icon': Icons.stars,
        'color': Colors.red,
      },
    ];

    return Column(
      children: achievements.map((achievement) {
        final id = achievement['id'] as String;
        final status = _achievementStatuses[id];

        return _buildAchievementCard(
          title: achievement['title'] as String,
          description: status?.description ?? 'Not started',
          icon: achievement['icon'] as IconData,
          unlocked: status?.unlocked ?? false,
          progress: status?.progress ?? 0.0,
          color: achievement['color'] as Color,
        );
      }).toList(),
    );
  }

  Widget _buildAchievementCard({
    required String title,
    required String description,
    required IconData icon,
    required bool unlocked,
    required double progress,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? color.withOpacity(0.5) : AppColors.secondary.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Achievement Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: unlocked ? color : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: unlocked ? Colors.white : Colors.grey.shade500,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Achievement Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: unlocked ? Colors.black : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (unlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'UNLOCKED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: unlocked ? Colors.grey.shade700 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Progress bar for locked achievements
          if (!unlocked && progress > 0) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
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
