import 'dart:io';
import 'dart:convert'; // for json
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 add this
import 'add_milestone_sheet.dart';

class MilestoneJourney extends StatefulWidget {
  const MilestoneJourney({super.key});

  @override
  State<MilestoneJourney> createState() => _MilestoneJourneyState();
}

class _MilestoneJourneyState extends State<MilestoneJourney> {
  List<Map<String, dynamic>> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones(); // 👈 load saved data on startup
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
    await _saveMilestones(); // 👈 persist after adding
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
              onPressed: () {
                // TODO: preview action
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: SvgPicture.asset(
                "assets/icons/play.svg",
                height: 23,
                width: 23,
                color: Colors.grey,
              ),
              label: const Text(
                "Preview",
                style: TextStyle(color: Colors.grey),
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
                  onTap: () {
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
                  },
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 30, color: Colors.grey),
                          SizedBox(height: 5),
                          Text(
                            "Add Image",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
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
                    image: FileImage(File(milestone["file"] as String)), // 👈 load from path
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
      ],
    );
  }
}
