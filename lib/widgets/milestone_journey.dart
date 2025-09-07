import 'package:flutter/material.dart';
import 'add_milestone_sheet.dart';

class MilestoneJourney extends StatelessWidget {
  const MilestoneJourney({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Milestone Journey",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 30, color: Colors.grey),
                  SizedBox(height: 5),
                  Text("Add Image"),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
