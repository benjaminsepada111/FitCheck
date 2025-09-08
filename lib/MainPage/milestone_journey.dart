import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 import for SVG
import 'add_milestone_sheet.dart';

class MilestoneJourney extends StatelessWidget {
  const MilestoneJourney({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Milestone Journey",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () {
                // TODO: Add preview action
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: SvgPicture.asset(
                "assets/icons/play.svg", // 👈 your SVG path
                height: 23,
                width: 23,
                color: Colors.grey, // 👈 keeps it grey like your UI
              ),
              label: const Text(
                "Preview",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => const AddMilestoneSheet(),
            );
          },
          child: Container(
            height: 180,
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
        ),
      ],
    );
  }
}
