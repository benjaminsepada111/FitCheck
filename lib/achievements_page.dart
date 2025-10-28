import 'package:flutter/material.dart';
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Your Statistics',
                          style: AppTextStyles.heading2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildStatisticsGrid(),
                    const SizedBox(height: 32),

                    // Achievements Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFA726),
                                    Color(0xFFFB8C00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Achievements',
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFA726), Color(0xFFFB8C00)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_achievements.where((a) => a['unlocked'] == true).length}/${_achievements.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Sen',
                            ),
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
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          label: 'Total Calories',
          value: _formatNumber(totalCaloriesConsumed),
          unit: 'kcal',
          icon: Icons.local_fire_department,
          gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
        ),
        _buildStatCard(
          label: 'Login Streak',
          value: totalLoginDays.toString(),
          unit: 'days',
          icon: Icons.calendar_today_rounded,
          gradientColors: [const Color(0xFF4E54C8), const Color(0xFF8F94FB)],
        ),
        _buildStatCard(
          label: 'Workouts',
          value: totalWorkouts.toString(),
          unit: 'sessions',
          icon: Icons.fitness_center_rounded,
          gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
        ),
        _buildStatCard(
          label: 'Meals Logged',
          value: _totalMealsLogged.toString(),
          unit: 'meals',
          icon: Icons.restaurant_rounded,
          gradientColors: [const Color(0xFFFA8BFF), const Color(0xFF2BD2FF)],
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, // Could add navigation to detailed stats in future
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Row 1: Icon and Data (value + unit)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    // Value and Unit
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Sen',
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
                                fontFamily: 'Sen',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: Label
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Sen',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
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

    // Dynamic calculation for perfect symmetry
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding =
        16.0; // Page padding (already applied by parent ScrollView)
    const gap = 8.0; // Reduced gap for tighter spacing between badges

    // Formula: availableWidth = gap + badgeWidth + gap + badgeWidth + gap
    // This creates symmetric spacing: [gap][badge][gap][badge][gap]
    final availableWidth = screenWidth - (2 * horizontalPadding);
    final badgeWidth = (availableWidth - (3 * gap)) / 2;

    // Calculate badge height (including title and progress text)
    // Badge image is circular, so use badgeWidth for diameter
    // Add space for title (2 lines max ~34px) + progress text (~18px) + spacing (~36px)
    final badgeImageSize =
        badgeWidth *
        0.92; // Increased to 92% of card width for larger, more prominent badges
    final cardHeight =
        badgeImageSize +
        88; // Badge + text space (increased for larger text and no overflow)

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: gap,
      ), // Creates [gap][badge][gap][badge][gap]
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: badgeWidth / cardHeight,
      ),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final achievement = _achievements[index];
        final iconName = achievement['icon'] as String;
        final icon = iconMap[iconName] ?? Icons.star;
        final imagePath = achievement['image'] as String?;
        final color = Color(achievement['color'] as int);
        final unlocked = achievement['unlocked'] as bool;
        final progress = (achievement['progress'] as num).toDouble();
        final currentValue = achievement['currentValue'] as int;
        final threshold = achievement['threshold'] as int;

        return _buildGridAchievementCard(
          title: achievement['title'] as String,
          description: achievement['description'] as String,
          icon: icon,
          imagePath: imagePath,
          unlocked: unlocked,
          color: color,
          progress: progress,
          currentValue: currentValue,
          threshold: threshold,
          badgeSize: badgeImageSize,
        );
      },
    );
  }

  Widget _buildGridAchievementCard({
    required String title,
    required String description,
    required IconData icon,
    String? imagePath,
    required bool unlocked,
    required Color color,
    required double progress,
    required int currentValue,
    required int threshold,
    required double badgeSize,
  }) {
    return GestureDetector(
      onTap: () => _showAchievementDetail(
        title: title,
        description: description,
        icon: icon,
        imagePath: imagePath,
        unlocked: unlocked,
        color: color,
        progress: progress,
        currentValue: currentValue,
        threshold: threshold,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Badge Image
            SizedBox(
              width: badgeSize,
              height: badgeSize,
              child: imagePath != null
                  ? ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            )
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                              0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                              0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                              0, 0, 0, 1, 0, // Alpha channel
                            ]),
                      child: Image.asset(
                        imagePath,
                        width: badgeSize,
                        height: badgeSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: badgeSize * 0.4,
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: badgeSize * 0.4,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: unlocked ? Colors.black : Colors.grey.shade600,
                  fontFamily: 'Sen',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 5),
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                unlocked ? 'Unlocked!' : '$currentValue/$threshold',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? color : Colors.grey.shade500,
                  fontFamily: 'Sen',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail({
    required String title,
    required String description,
    required IconData icon,
    String? imagePath,
    required bool unlocked,
    required Color color,
    required double progress,
    required int currentValue,
    required int threshold,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large Badge
              SizedBox(
                width: 180,
                height: 180,
                child: imagePath != null
                    ? ColorFiltered(
                        colorFilter: unlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                                0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                                0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                                0, 0, 0, 1, 0, // Alpha channel
                              ]),
                        child: Image.asset(
                          imagePath,
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: Colors.white, size: 90),
                            );
                          },
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 90),
                      ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Sen',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: unlocked
                      ? color.withOpacity(0.15)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? color : Colors.grey.shade600,
                    fontFamily: 'Sen',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mission',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            fontFamily: 'Sen',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontFamily: 'Sen',
                      ),
                    ),
                  ],
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 20),
                // Progress Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              fontFamily: 'Sen',
                            ),
                          ),
                          Text(
                            '$currentValue / $threshold',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontFamily: 'Sen',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Sen',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Sen',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
