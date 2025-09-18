import 'dart:io';
import 'dart:convert'; // for json
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_milestone_sheet.dart';
import 'milestone_preview.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart'; // Add this import

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
  List<Map<String, dynamic>> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('milestones') ?? [];
    setState(() {
      _milestones = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      // Convert date string back to DateTime
      for (var m in _milestones) {
        m["date"] = DateTime.parse(m["date"]);
      }
    });
  }

  Future<void> _saveMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _milestones.map((e) {
      final copy = Map<String, dynamic>.from(e);
      copy["date"] = (copy["date"] as DateTime).toIso8601String();
      return jsonEncode(copy);
    }).toList();
    await prefs.setStringList('milestones', data);
  }

  void _addMilestone(Map<String, dynamic> milestone) async {
    setState(() {
      _milestones.insert(0, milestone);
    });
    await _saveMilestones();
  }

  void _showNoChallengeMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Start a Challenge',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To track your milestone journey, you need to start a challenge first.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Milestone photos help you visualize your progress throughout your fitness journey!',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to create challenge sheet
              if (widget.onCreateChallenge != null) {
                widget.onCreateChallenge!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create Challenge'),
          ),
        ],
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
      final d = m["date"] as DateTime;
      return d.year == today.year && d.month == today.month && d.day == today.day;
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _milestones.isEmpty ? Colors.grey : Colors.white,
                backgroundColor: _milestones.isEmpty
                    ? Colors.grey.shade200
                    : AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: SvgPicture.asset(
                "assets/icons/play.svg",
                height: 23,
                width: 23,
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
        const SizedBox(height: 10),

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
                        onSave: _addMilestone,
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
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Colors.grey,
                                size: 20,
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
                  image: DecorationImage(
                    image: FileImage(File(milestone["file"] as String)),
                    fit: BoxFit.cover,
                  ),
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
                      _formatDate(milestone["date"] as DateTime),
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

        // Add informational text when no challenge is active
        if (!hasActiveChallenge) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Start a challenge to begin tracking your milestone journey and progress photos!",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}