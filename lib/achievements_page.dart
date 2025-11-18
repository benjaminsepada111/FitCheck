import 'package:flutter/material.dart';
import 'package:capstone_project/app_text_styles.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Check and unlock achievements based on current stats
      await UserAchievementService.checkAndUnlockAchievements();

      // Load achievements from Firebase
      final achievements = await UserAchievementService.getAllAchievementsWithDetails();

      if (mounted) {
        setState(() {
          _achievements = achievements;
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
          'Achievements',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(r.size(16), r.size(12), r.size(16), r.size(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Achievements Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(r.size(8)),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
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
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.size(12),
                            vertical: r.size(6),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(r.size(20)),
                          ),
                          child: Text(
                            '${_achievements.where((a) => a['unlocked'] == true).length}/${_achievements.length}',
                            style: AppTextStyles.button.copyWith(
                              fontSize: r.font(14, min: 12, max: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ResponsiveGap(12),
                    // Achievements List
                    _buildAchievementsList(),
                  ],
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
            style: AppTextStyles.body.copyWith(
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
    final gap = r.size(6); // Reduced gap for tighter spacing between badges

    // Formula: availableWidth = gap + badgeWidth + gap + badgeWidth + gap
    // This creates symmetric spacing: [gap][badge][gap][badge][gap]
    final availableWidth = screenWidth - (2 * horizontalPadding);
    final badgeWidth = (availableWidth - (3 * gap)) / 2;

    // Calculate badge height (including title and progress text)
    // Badge image is circular, so use badgeWidth for diameter
    // Add space for title (2 lines max ~34px) + progress text (~18px) + spacing (~36px)
    final badgeImageSize =
        badgeWidth *
        0.90; // Slightly smaller for tighter layout
    final cardHeight =
        badgeImageSize +
        r.size(72); // Reduced text space for compact layout

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
            ResponsiveGap(2),
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
            ResponsiveGap(4),
            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.size(4)),
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: r.font(13, min: 11, max: 15),
                  fontWeight: FontWeight.bold,
                  color: unlocked ? Colors.black : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ResponsiveGap(2),
            // Progress indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.size(4)),
              child: Text(
                unlocked ? 'Unlocked!' : '$currentValue/$threshold',
                style: AppTextStyles.caption.copyWith(
                  fontSize: r.font(11, min: 10, max: 13),
                  fontWeight: FontWeight.w600,
                  color: unlocked ? color : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ResponsiveGap(2),
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
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: r.font(24, min: 20, max: 28),
                    color: AppColors.secondary,
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
                        ? AppColors.secondary.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(r.size(20)),
                  ),
                  child: Text(
                    unlocked ? 'UNLOCKED' : 'LOCKED',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: r.font(12, min: 10, max: 14),
                      fontWeight: FontWeight.bold,
                      color: unlocked ? AppColors.secondary : Colors.grey.shade600,
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
                            style: AppTextStyles.body.copyWith(
                              fontSize: r.font(14, min: 12, max: 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      ResponsiveGap(8),
                      Text(
                        description,
                        style: AppTextStyles.body.copyWith(
                          fontSize: r.font(14, min: 12, max: 16),
                          color: Colors.grey.shade700,
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
                      color: AppColors.secondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(r.size(12)),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: AppTextStyles.body.copyWith(
                                fontSize: r.font(14, min: 12, max: 16),
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '$currentValue / $threshold',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: r.font(16, min: 14, max: 18),
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
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
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                            minHeight: r.size(8),
                          ),
                        ),
                        ResponsiveGap(8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% Complete',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: r.font(12, min: 10, max: 14),
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
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
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: r.size(16)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.size(12)),
                      ),
                      elevation: 0,
                      minimumSize: Size(double.infinity, r.tapTarget(44)),
                    ),
                    child: Text(
                      'Close',
                      style: AppTextStyles.button.copyWith(
                        fontSize: r.font(16, min: 14, max: 18),
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
