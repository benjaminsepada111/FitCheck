import 'package:flutter/material.dart';
import 'package:capstone_project/app_text_styles.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/services/statistics_service.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';

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
    final r = context.responsive;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: r.size(24)),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: r.tapTarget(44),
            minHeight: r.tapTarget(44),
          ),
        ),
        title: Text(
          'Achievements & Stats',
          style: TextStyle(
            color: Colors.black,
            fontSize: r.font(20, min: 18, max: 24),
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
                padding: EdgeInsets.fromLTRB(r.size(16), r.size(16), r.size(16), r.size(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Section
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(r.size(8)),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(r.size(10)),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: r.size(20),
                          ),
                        ),
                        ResponsiveGap.horizontal(12),
                        Text(
                          'Your Statistics',
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: r.font(20, min: 18, max: 24),
                          ),
                        ),
                      ],
                    ),
                    ResponsiveGap(20),
                    _buildStatisticsGrid(),
                    ResponsiveGap(32),

                    // Achievements Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(r.size(8)),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFA726),
                                    Color(0xFFFB8C00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(r.size(10)),
                              ),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.white,
                                size: r.size(20),
                              ),
                            ),
                            ResponsiveGap.horizontal(12),
                            Text(
                              'Achievements',
                              style: AppTextStyles.heading2.copyWith(
                                fontSize: r.font(20, min: 18, max: 24),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.size(12),
                            vertical: r.size(6),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFA726), Color(0xFFFB8C00)],
                            ),
                            borderRadius: BorderRadius.circular(r.size(20)),
                          ),
                          child: Text(
                            '${_achievements.where((a) => a['unlocked'] == true).length}/${_achievements.length}',
                            style: TextStyle(
                              fontSize: r.font(14, min: 12, max: 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Sen',
                            ),
                          ),
                        ),
                      ],
                    ),
                    ResponsiveGap(16),
                    _buildAchievementsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatisticsGrid() {
    final r = context.responsive;

    // Extract stats from Firebase user stats
    final totalCaloriesConsumed = _userStats['total_calories_consumed'] ?? 0;
    final totalLoginDays = _userStats['total_login_days'] ?? 0;
    final totalWorkouts = _userStats['total_workouts'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: r.size(16),
      mainAxisSpacing: r.size(16),
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
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.size(20)),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: r.size(12),
            offset: Offset(0, r.size(6)),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r.size(20)),
          onTap: () {}, // Could add navigation to detailed stats in future
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.size(16), vertical: r.size(14)),
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
                      padding: EdgeInsets.all(r.size(8)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(r.size(10)),
                      ),
                      child: Icon(icon, color: Colors.white, size: r.size(20)),
                    ),
                    ResponsiveGap.horizontal(10),
                    // Value and Unit
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: r.font(28, min: 20, max: 32),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Sen',
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ResponsiveGap.horizontal(4),
                          Padding(
                            padding: EdgeInsets.only(bottom: r.size(2)),
                            child: Text(
                              unit,
                              style: TextStyle(
                                fontSize: r.font(13, min: 11, max: 15),
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontFamily: 'Sen',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ResponsiveGap(10),
                // Row 2: Label
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.font(13, min: 11, max: 15),
                    color: Colors.white.withValues(alpha: 0.9),
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
    final r = context.responsive;

    if (_achievements.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.size(32)),
          child: Text(
            'No achievements available yet.\nComplete activities to unlock achievements!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: r.font(14, min: 12, max: 16),
            ),
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
    final horizontalPadding = r.size(16); // Page padding (already applied by parent ScrollView)
    final gap = r.size(8); // Reduced gap for tighter spacing between badges

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
        r.size(88); // Badge + text space (increased for larger text and no overflow)

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
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
    final r = context.responsive;

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
          borderRadius: BorderRadius.circular(r.size(16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ResponsiveGap(4),
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
            ResponsiveGap(8),
            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.size(4)),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: r.font(14, min: 12, max: 16),
                  fontWeight: FontWeight.bold,
                  color: unlocked ? Colors.black : Colors.grey.shade600,
                  fontFamily: 'Sen',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ResponsiveGap(5),
            // Progress indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.size(4)),
              child: Text(
                unlocked ? 'Unlocked!' : '$currentValue/$threshold',
                style: TextStyle(
                  fontSize: r.font(12, min: 10, max: 14),
                  fontWeight: FontWeight.w600,
                  color: unlocked ? color : Colors.grey.shade500,
                  fontFamily: 'Sen',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ResponsiveGap(4),
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
      builder: (dialogContext) {
        final r = dialogContext.responsive;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.size(24))),
          child: Container(
            padding: EdgeInsets.all(r.size(24)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.size(24)),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Large Badge
                ResponsiveSizedBox(
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
                            width: r.size(180),
                            height: r.size(180),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: Colors.white, size: r.size(90)),
                              );
                            },
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: r.size(90)),
                        ),
                ),
                ResponsiveGap(20),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.font(24, min: 20, max: 28),
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Sen',
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveGap(12),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.size(16),
                    vertical: r.size(6),
                  ),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? color.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(r.size(20)),
                  ),
                  child: Text(
                    unlocked ? 'UNLOCKED' : 'LOCKED',
                    style: TextStyle(
                      fontSize: r.font(12, min: 10, max: 14),
                      fontWeight: FontWeight.bold,
                      color: unlocked ? color : Colors.grey.shade600,
                      fontFamily: 'Sen',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ResponsiveGap(20),
                // Description
                Container(
                  padding: EdgeInsets.all(r.size(16)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(r.size(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: r.size(18),
                            color: Colors.grey.shade700,
                          ),
                          ResponsiveGap.horizontal(8),
                          Text(
                            'Mission',
                            style: TextStyle(
                              fontSize: r.font(14, min: 12, max: 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              fontFamily: 'Sen',
                            ),
                          ),
                        ],
                      ),
                      ResponsiveGap(8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: r.font(14, min: 12, max: 16),
                          color: Colors.grey.shade700,
                          fontFamily: 'Sen',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!unlocked) ...[
                  ResponsiveGap(20),
                  // Progress Section
                  Container(
                    padding: EdgeInsets.all(r.size(16)),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(r.size(12)),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: r.font(14, min: 12, max: 16),
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                fontFamily: 'Sen',
                              ),
                            ),
                            Text(
                              '$currentValue / $threshold',
                              style: TextStyle(
                                fontSize: r.font(16, min: 14, max: 18),
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontFamily: 'Sen',
                              ),
                            ),
                          ],
                        ),
                        ResponsiveGap(12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.size(8)),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: r.size(8),
                          ),
                        ),
                        ResponsiveGap(8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% Complete',
                          style: TextStyle(
                            fontSize: r.font(12, min: 10, max: 14),
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Sen',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ResponsiveGap(24),
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: r.size(14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.size(12)),
                      ),
                      elevation: 0,
                      minimumSize: Size(double.infinity, r.tapTarget(44)),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: r.font(16, min: 14, max: 18),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Sen',
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
}
