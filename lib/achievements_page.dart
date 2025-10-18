import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/app_text_styles.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/services/statistics_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _userStats = {};
  List<Map<String, dynamic>> _achievements = [];
  int _totalMealsLogged = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load user stats, achievements, and total meals from Firebase in parallel
      final results = await Future.wait([
        UserAchievementService.getUserStats(),
        UserAchievementService.getAllAchievementsWithDetails(),
        StatisticsService.getMealsLogged(),
      ]);

      if (mounted) {
        setState(() {
          _userStats = results[0] as Map<String, dynamic>;
          _achievements = results[1] as List<Map<String, dynamic>>;
          _totalMealsLogged = results[2] as int;
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

  Future<void> _refreshData() async {
    // Refresh achievements from server
    await UserAchievementService.checkAndUnlockAchievements();
    await _loadData();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Section
                    const Text(
                      'Your Statistics',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 16),
                    _buildStatisticsGrid(),
                    const SizedBox(height: 24),

                    // Achievements Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Achievements',
                          style: AppTextStyles.heading2,
                        ),
                        Text(
                          '${_achievements.where((a) => a['unlocked'] == true).length}/${_achievements.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAchievementsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatisticsGrid() {
    // Extract stats from Firebase user stats
    final totalCaloriesConsumed = _userStats['total_calories_consumed'] ?? 0;
    final totalLoginDays = _userStats['total_login_days'] ?? 0;
    final totalWorkouts = _userStats['total_workouts'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: [
        _buildStatCard(
          label: 'Calories Consumed',
          value: totalCaloriesConsumed.toString(),
        ),
        _buildStatCard(
          label: 'Login',
          value: totalLoginDays.toString(),
        ),
        _buildStatCard(
          label: 'Workouts',
          value: totalWorkouts.toString(),
        ),
        _buildStatCard(
          label: 'Meals',
          value: _totalMealsLogged.toString(),
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
    if (_achievements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No achievements available yet.\nComplete activities to unlock achievements!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Map icon names to IconData
    final iconMap = {
      'flag': Icons.flag,
      'local_fire_department': Icons.local_fire_department,
      'calendar_today': Icons.calendar_today,
      'photo_camera': Icons.photo_camera,
      'restaurant': Icons.restaurant,
      'fitness_center': Icons.fitness_center,
      'emoji_events': Icons.emoji_events,
    };

    return Column(
      children: _achievements.map((achievement) {
        final iconName = achievement['icon'] as String;
        final icon = iconMap[iconName] ?? Icons.star;
        final color = Color(achievement['color'] as int);
        final unlocked = achievement['unlocked'] as bool;
        final progress = (achievement['progress'] as num).toDouble();
        final currentValue = achievement['currentValue'] as int;
        final threshold = achievement['threshold'] as int;

        // Build description with progress
        String description = achievement['description'] as String;
        if (!unlocked) {
          description = '$description ($currentValue/$threshold)';
        }

        return _buildAchievementCard(
          title: achievement['title'] as String,
          description: description,
          icon: icon,
          unlocked: unlocked,
          color: color,
          progress: progress,
        );
      }).toList(),
    );
  }

  Widget _buildAchievementCard({
    required String title,
    required String description,
    required IconData icon,
    required bool unlocked,
    required Color color,
    required double progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? color.withOpacity(0.5)
              : AppColors.secondary.shade200,
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
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
