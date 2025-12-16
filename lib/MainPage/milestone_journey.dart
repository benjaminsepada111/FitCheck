import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'add_milestone_sheet.dart';
import 'milestone_preview.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/models/milestone.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/services/NotificationHelper.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
import '../app_text_styles.dart';

class MilestoneJourney extends StatefulWidget {
  final Challenge? currentChallenge;
  final VoidCallback? onCreateChallenge;

  const MilestoneJourney({
    super.key,
    this.currentChallenge,
    this.onCreateChallenge,
  });

  @override
  State<MilestoneJourney> createState() => _MilestoneJourneyState();
}

class _MilestoneJourneyState extends State<MilestoneJourney>
    with AutomaticKeepAliveClientMixin {
  List<Milestone> _milestones = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _lastLoadedChallengeId;
  final NotificationService _notificationService = NotificationService();

  // Key to force rebuild of milestone images
  int _refreshKey = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  @override
  void didUpdateWidget(MilestoneJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChallenge?.id != widget.currentChallenge?.id) {
      _hasLoadedOnce = false;
      _loadMilestones();
    }
  }

  Future<void> _loadMilestones({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh &&
        _hasLoadedOnce &&
        _lastLoadedChallengeId == widget.currentChallenge?.id) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final milestones = widget.currentChallenge != null
          ? await MilestoneService.getAllMilestones(
        challengeId: widget.currentChallenge!.id,
      )
          : <Milestone>[];

      if (mounted) {
        setState(() {
          _milestones = milestones;
          _hasLoadedOnce = true;
          _lastLoadedChallengeId = widget.currentChallenge?.id;
          // Increment refresh key to force rebuild of image widgets
          if (forceRefresh) {
            _refreshKey++;
          }
        });

        _updateNotificationStatus();
      }
    } catch (e) {
      // Error loading milestones
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateNotificationStatus() async {
    if (widget.currentChallenge == null) {
      await _notificationService.cancelMilestoneReminder();
      return;
    }

    final hasToday = _hasTodayMilestone();

    if (hasToday) {
      await _notificationService.cancelMilestoneReminder();
      debugPrint('✅ Milestone exists for today - all reminders cancelled');
    } else {
      debugPrint('📅 No milestone today - reminders controlled by user settings');
    }
  }

  Future<void> _addMilestone(Milestone milestone, {File? imageFile}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.currentChallenge == null) {
        throw Exception('No active challenge');
      }
      final success = await MilestoneService.saveMilestone(
        milestone,
        imageFile: imageFile,
        challengeId: widget.currentChallenge!.id,
      );
      if (success) {
        await _loadMilestones(forceRefresh: true);

        if (mounted) {
          await NotificationHelper.createMilestonePhotoNotification();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Milestone saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          await _notificationService.cancelMilestoneReminder();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save milestone. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An error occurred while saving milestone.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showNoChallengeMessage() {
    final r = context.responsive;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.size(24))),
        child: Container(
          padding: EdgeInsets.all(r.size(28)),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(r.size(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(r.size(20)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      blurRadius: r.size(20),
                      offset: Offset(0, r.size(8)),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.flag_outlined,
                  color: Colors.white,
                  size: r.size(40),
                ),
              ),
              ResponsiveGap(24),
              Text(
                'Start Your Journey',
                style: TextStyle(
                  fontSize: r.font(24, min: 20, max: 28),
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ResponsiveGap(12),
              Text(
                'Create a challenge to begin tracking your milestone progress and celebrate your achievements!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.font(15, min: 13, max: 17),
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              ResponsiveGap(24),
              Container(
                padding: EdgeInsets.all(r.size(16)),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(r.size(16)),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    width: r.size(1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.size(8)),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.size(8)),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.secondary,
                        size: r.size(20),
                      ),
                    ),
                    ResponsiveGap.horizontal(12),
                    Expanded(
                      child: Text(
                        'Track your transformation with milestone photos',
                        style: TextStyle(
                          fontSize: r.font(13, min: 12, max: 15),
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ResponsiveGap(28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: r.size(16)),
                        minimumSize: Size(r.tapTarget(44), r.tapTarget(44)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.size(12)),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: r.font(16, min: 14, max: 18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ResponsiveGap.horizontal(12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (widget.onCreateChallenge != null) {
                          widget.onCreateChallenge!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: r.size(16)),
                        minimumSize: Size(r.tapTarget(44), r.tapTarget(44)),
                        elevation: 0,
                        shadowColor: AppColors.secondary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.size(12)),
                        ),
                      ),
                      child: Text(
                        'Create',
                        style: TextStyle(
                          fontSize: r.font(16, min: 14, max: 18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final milestoneDate = DateTime(date.year, date.month, date.day);

    if (milestoneDate == today) return "Today";
    if (milestoneDate == yesterday) return "Yesterday";
    return DateFormat("MMM d, yyyy").format(date);
  }

  bool _hasTodayMilestone() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var milestone in _milestones) {
      final milestoneDate = DateTime(
        milestone.date.year,
        milestone.date.month,
        milestone.date.day,
      );

      if (milestoneDate == today) {
        return true;
      }
    }

    return false;
  }

  // ✅ FIXED: Build timeline with missed days inserted
  List<dynamic> _buildTimelineWithMissedDays() {
    if (_milestones.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<dynamic> timeline = [];

    // Sort milestones by date descending (newest first) - matching your original order
    final sortedMilestones = List<Milestone>.from(_milestones)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Get the most recent milestone date
    final mostRecentDate = DateTime(
      sortedMilestones[0].date.year,
      sortedMilestones[0].date.month,
      sortedMilestones[0].date.day,
    );

    // ✅ FIX: Add missed days between today and most recent milestone (excluding today)
    if (mostRecentDate.isBefore(today)) {
      DateTime checkDate = today.subtract(const Duration(days: 1));
      while (checkDate.isAfter(mostRecentDate)) {
        timeline.add(checkDate); // Add missed day
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    // Now add milestones and gaps between them
    for (int i = 0; i < sortedMilestones.length; i++) {
      // Add the milestone
      timeline.add(sortedMilestones[i]);

      // Check if there's a next milestone (older date)
      if (i < sortedMilestones.length - 1) {
        final currentDate = DateTime(
          sortedMilestones[i].date.year,
          sortedMilestones[i].date.month,
          sortedMilestones[i].date.day,
        );

        final nextDate = DateTime(
          sortedMilestones[i + 1].date.year,
          sortedMilestones[i + 1].date.month,
          sortedMilestones[i + 1].date.day,
        );

        // Add missed days between current and next milestone
        DateTime checkDate = currentDate.subtract(const Duration(days: 1));
        while (checkDate.isAfter(nextDate)) {
          timeline.add(checkDate); // Add DateTime object for missed day
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }
    }

    return timeline;
  }

  // Build missed day card UI
  Widget _buildMissedDayCard(BuildContext context, DateTime date) {
    final r = context.responsive;
    return Container(
      width: r.size(120),
      decoration: BoxDecoration(
        color: const Color(0xFF121C29),
        borderRadius: BorderRadius.circular(r.size(12)),

      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: r.size(32),
                  color: AppColors.secondary,
                ),
                ResponsiveGap(8),
                Text(
                  "Missed",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.font(14, min: 12, max: 16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveGap(2),
                Text(
                  "Day",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: r.font(12, min: 11, max: 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: r.size(6),
                horizontal: r.size(6),
              ),

              child: Text(
                _formatDate(date),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(12, min: 11, max: 14),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = context.responsive;
    final hasToday = _hasTodayMilestone();
    final hasActiveChallenge = widget.currentChallenge != null;
    final timeline = _buildTimelineWithMissedDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Milestone Journey", style: AppTextStyles.heading2),
            TextButton.icon(
              onPressed: _milestones.isEmpty
                  ? null
                  : () async {
                if (widget.currentChallenge != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MilestonePreviewPage(
                        milestones: List<Milestone>.from(_milestones), // Pass a copy to avoid reference issues
                        onMilestonesChanged: () {
                          // Force refresh immediately when callback is triggered
                          _loadMilestones(forceRefresh: true);
                        },
                        challengeId: widget.currentChallenge!.id,
                      ),
                    ),
                  );
                  // Force refresh after returning from preview page
                  await _loadMilestones(forceRefresh: true);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor:
                _milestones.isEmpty ? Colors.grey : Colors.white,
                backgroundColor: _milestones.isEmpty
                    ? Colors.grey.shade200
                    : AppColors.secondary,
                padding: EdgeInsets.symmetric(
                  horizontal: r.size(16),
                  vertical: r.size(12),
                ),
                minimumSize: Size(r.size(100), r.tapTarget(48)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.size(12)),
                ),
              ),
              icon: SvgPicture.asset(
                "assets/icons/play.svg",
                height: r.size(20),
                width: r.size(20),
                colorFilter: ColorFilter.mode(
                  _milestones.isEmpty ? Colors.grey : Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              label: Text(
                "Preview",
                style: TextStyle(
                  color: _milestones.isEmpty ? Colors.grey : Colors.white,
                  fontSize: r.font(14, min: 12, max: 16),
                ),
              ),
            ),
          ],
        ),
        ResponsiveGap(6),
        if (_isLoading)
          ResponsiveSizedBox(
            height: 180,
            child: Center(
              child: FitCheckLoader(),
            ),
          )
        else
          ResponsiveSizedBox(
            height: 180,
            child: ListView.separated(
              key: ValueKey(_refreshKey), // Force rebuild when refresh key changes
              scrollDirection: Axis.horizontal,
              itemCount: timeline.length + (hasToday ? 0 : 1),
              separatorBuilder: (context, index) => ResponsiveGap.horizontal(12),
              itemBuilder: (context, index) {
                if (!hasToday && index == 0) {
                  return GestureDetector(
                    onTap: hasActiveChallenge
                        ? () async {
                      final todayMilestone =
                      await MilestoneService.getMilestoneForDate(
                        DateTime.now(),
                        challengeId: widget.currentChallenge!.id,
                      );

                      if (todayMilestone != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'You have already uploaded a milestone photo for today!'),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(r.size(20)),
                          ),
                        ),
                        builder: (context) => AddMilestoneSheet(
                          selectedDate: DateTime.now(),
                          challengeId: widget.currentChallenge!.id,
                          onSave: (milestone, imageFile) =>
                              _addMilestone(
                                milestone,
                                imageFile: imageFile,
                              ),
                        ),
                      );
                    }
                        : _showNoChallengeMessage,
                    child: Container(
                      width: r.size(120),
                      decoration: BoxDecoration(
                        color: hasActiveChallenge
                            ? Colors.grey.shade100
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(r.size(12)),
                        border: hasActiveChallenge
                            ? null
                            : Border.all(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid,
                          width: r.size(1),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: r.size(30),
                                  color: hasActiveChallenge
                                      ? Colors.grey
                                      : Colors.grey.shade500,
                                ),
                                ResponsiveGap(5),
                                Text(
                                  hasActiveChallenge
                                      ? "Add Image"
                                      : "Start Challenge",
                                  style: TextStyle(
                                    color: hasActiveChallenge
                                        ? Colors.grey
                                        : Colors.grey.shade600,
                                    fontSize: r.font(
                                        hasActiveChallenge ? 14 : 12,
                                        min: 11,
                                        max: 16),
                                    fontWeight: hasActiveChallenge
                                        ? FontWeight.normal
                                        : FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (!hasActiveChallenge) ...[
                                  ResponsiveGap(4),
                                  Text(
                                    "First",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: r.font(12, min: 11, max: 14),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!hasActiveChallenge)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius:
                                  BorderRadius.circular(r.size(12)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                // Use timeline with missed days
                final timelineIndex = index - (hasToday ? 0 : 1);
                final item = timeline[timelineIndex];

                // Check if item is a DateTime (missed day) or Milestone
                if (item is DateTime) {
                  return _buildMissedDayCard(context, item);
                }

                // Original milestone card code with unique key for image refresh
                final milestone = item as Milestone;
                final imageKey = Key('milestone_${milestone.id}_${milestone.updatedAt.millisecondsSinceEpoch}_$_refreshKey');

                return Container(
                  width: r.size(120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.size(12)),
                    color: Colors.grey.shade200,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (milestone.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.size(12)),
                          child: Image.network(
                            milestone.imageUrl!,
                            key: imageKey, // Add unique key for image refresh
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: FitCheckLoader(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              if (milestone.imagePath != null) {
                                return Image.file(
                                  File(milestone.imagePath!),
                                  key: imageKey,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey.shade400,
                                        size: r.size(40),
                                      ),
                                    );
                                  },
                                );
                              }
                              return Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade400,
                                  size: r.size(40),
                                ),
                              );
                            },
                          ),
                        )
                      else if (milestone.imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.size(12)),
                          child: Image.file(
                            File(milestone.imagePath!),
                            key: imageKey, // Add unique key for image refresh
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade400,
                                  size: r.size(40),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.photo_outlined,
                            color: Colors.grey.shade400,
                            size: r.size(40),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: r.size(4),
                            horizontal: r.size(6),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(r.size(12)),
                            ),
                          ),
                          child: Text(
                            _formatDate(milestone.date),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.font(12, min: 11, max: 14),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}