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
  bool _hasLoadedOnce = false; // Cache flag
  String? _lastLoadedChallengeId; // Track which challenge we loaded
  final NotificationService _notificationService = NotificationService();

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  @override
  void didUpdateWidget(MilestoneJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if challenge actually changed
    if (oldWidget.currentChallenge?.id != widget.currentChallenge?.id) {
      _hasLoadedOnce = false; // Reset cache on challenge change
      _loadMilestones();
    }
  }

  Future<void> _loadMilestones({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Skip loading if already loaded for this challenge (unless forced)
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
          _hasLoadedOnce = true; // Mark as loaded
          _lastLoadedChallengeId = widget.currentChallenge?.id; // Remember challenge
        });

        // Check if notification should be scheduled or cancelled
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
    // Only schedule notifications if there's an active challenge
    if (widget.currentChallenge == null) {
      await _notificationService.cancelMilestoneReminder();
      return;
    }

    final hasToday = _hasTodayMilestone();

    if (hasToday) {
      // User has added milestone today - cancel all reminders
      await _notificationService.cancelMilestoneReminder();
      debugPrint('✅ Milestone exists for today - all reminders cancelled');
    } else {
      // User hasn't added milestone today - schedule 2 PM and 8 PM reminders
      await _notificationService.scheduleDailyMilestoneReminders();
      debugPrint('📅 No milestone today - reminders scheduled for 2 PM and 8 PM');
    }
  }


  // NEW METHOD: Show immediate notification if user hasn't added photo today
  Future<void> _showImmediateReminderIfNeeded() async {
    final now = DateTime.now();

    // Only show immediate notification if it's after 12 PM (noon)
    // This prevents spamming user early in the morning
    if (now.hour >= 12) {
      await _notificationService.showInstantNotification(
        title: '📸 Time to Add Your Milestone!',
        body: "You haven't added your milestone photo today. Tap to add now!",
        payload: 'add_milestone_now',
      );
      debugPrint('📢 Immediate milestone reminder shown (after 12 PM)');
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
        await _loadMilestones(forceRefresh: true); // Force refresh after adding milestone

        if (mounted) {
          // Show milestone saved notification
          await _notificationService.showMilestoneSavedNotification();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Milestone saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Cancel today's reminder since milestone is now added
          await _notificationService.cancelMilestoneReminder();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save milestone. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while saving milestone.'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final r = context.responsive;
    final hasToday = _hasTodayMilestone();
    final hasActiveChallenge = widget.currentChallenge != null;

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
                        milestones: _milestones,
                        onMilestonesChanged: () {
                          _loadMilestones();
                        },
                        challengeId: widget.currentChallenge!.id,
                      ),
                    ),
                  );
                  // Reload milestones when returning from preview
                  _loadMilestones();
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
              scrollDirection: Axis.horizontal,
              itemCount: _milestones.length + (hasToday ? 0 : 1),
              separatorBuilder: (context, index) => ResponsiveGap.horizontal(12),
              itemBuilder: (context, index) {
                if (!hasToday && index == 0) {
                  return GestureDetector(
                    onTap: hasActiveChallenge
                        ? () async {
                      // Check if today's milestone already exists
                      final todayMilestone =
                      await MilestoneService.getMilestoneForDate(
                        DateTime.now(),
                        challengeId: widget.currentChallenge!.id,
                      );

                      if (todayMilestone != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'You have already uploaded a milestone photo for today!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (!mounted) return;

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(r.size(20)),
                          ),
                        ),
                        builder: (context) => AddMilestoneSheet(
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
                                    fontSize: r.font(hasActiveChallenge ? 14 : 12, min: 11, max: 16),
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
                                  borderRadius: BorderRadius.circular(r.size(12)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final milestone = _milestones[index - (hasToday ? 0 : 1)];
                return Container(
                  width: r.size(120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.size(12)),
                    color: Colors.grey.shade200,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image layer with error handling
                      if (milestone.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.size(12)),
                          child: Image.network(
                            milestone.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: FitCheckLoader(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // Try to show local image if network fails
                              if (milestone.imagePath != null) {
                                return Image.file(
                                  File(milestone.imagePath!),
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
                      // Date label overlay
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
