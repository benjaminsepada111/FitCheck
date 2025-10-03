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
import '../app_text_styles.dart';

class MilestoneJourney extends StatefulWidget {
  final Challenge? currentChallenge;
  final VoidCallback? onCreateChallenge; // Add callback for creating challenge

  const MilestoneJourney({
    super.key,
    this.currentChallenge,
    this.onCreateChallenge, // Add this parameter
  });

  @override
  State<MilestoneJourney> createState() => _MilestoneJourneyState();
}

class _MilestoneJourneyState extends State<MilestoneJourney> {
  List<Milestone> _milestones = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final milestones = await MilestoneService.getAllMilestones();
      setState(() {
        _milestones = milestones;
      });
    } catch (e) {
      print('Error loading milestones: $e');
      // Show error to user if needed
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMilestone(Milestone milestone, {File? imageFile}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await MilestoneService.saveMilestone(milestone, imageFile: imageFile);
      if (success) {
        setState(() {
          _milestones.insert(0, milestone);
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save milestone. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error saving milestone: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while saving milestone.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNoChallengeMessage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),

          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Start Your Journey',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Create a challenge to begin tracking your milestone progress and celebrate your achievements!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Track your transformation with milestone photos',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shadowColor: AppColors.secondary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 16,
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
    final today = DateTime.now();
    return _milestones.any((m) {
      return m.date.year == today.year && m.date.month == today.month && m.date.day == today.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasToday = _hasTodayMilestone();
    final hasActiveChallenge = widget.currentChallenge != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header Row ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Milestone Journey",
              style: AppTextStyles.heading2,
            ),
            TextButton.icon(
              onPressed: _milestones.isEmpty
                  ? null // disable if no milestones
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MilestonePreviewPage(
                      milestones: _milestones,
                      onMilestonesChanged: () {
                        // Refresh milestones when changes are made
                        _loadMilestones();
                      },
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _milestones.isEmpty ? Colors.grey : Colors.white,
                backgroundColor: _milestones.isEmpty
                    ? Colors.grey.shade200
                    : AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(100, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: SvgPicture.asset(
                "assets/icons/play.svg",
                height: 20,
                width: 20,
                color: _milestones.isEmpty ? Colors.grey : Colors.white,
              ),
              label: Text(
                "Preview",
                style: TextStyle(
                  color: _milestones.isEmpty ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),


        // --- Horizontal List ---
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _milestones.length + (hasToday ? 0 : 1),
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (!hasToday && index == 0) {
                return GestureDetector(
                  onTap: hasActiveChallenge
                      ? () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => AddMilestoneSheet(
                        onSave: (milestone, imageFile) => _addMilestone(milestone, imageFile: imageFile),
                      ),
                    );
                  }
                      : _showNoChallengeMessage, // Show message if no challenge
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: hasActiveChallenge
                          ? Colors.grey.shade100
                          : Colors.grey.shade300, // Darker when disabled
                      borderRadius: BorderRadius.circular(12),
                      border: hasActiveChallenge
                          ? null
                          : Border.all(
                        color: Colors.grey.shade400,
                        style: BorderStyle.solid,
                        width: 1,
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
                                size: 30,
                                color: hasActiveChallenge
                                    ? Colors.grey
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                hasActiveChallenge
                                    ? "Add Image"
                                    : "Start Challenge",
                                style: TextStyle(
                                  color: hasActiveChallenge
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                  fontSize: hasActiveChallenge ? 14 : 12,
                                  fontWeight: hasActiveChallenge
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!hasActiveChallenge) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "First",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
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
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),

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
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: milestone.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(milestone.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : milestone.imagePath != null
                      ? DecorationImage(
                          image: FileImage(File(milestone.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: milestone.imageUrl == null && milestone.imagePath == null
                    ? Colors.grey.shade200
                    : null,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Text(
                      _formatDate(milestone.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

      ],
    );
  }
}