import 'package:flutter/material.dart';

class Trackers extends StatelessWidget {
  const Trackers({super.key});

  Widget _buildTracker(String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.deepPurple, width: 2),
            ),
            child: const Text("-/-"),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.blue)),
          const Text("0% of Goal", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Trackers",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTracker("Calories"),
            _buildTracker("Water"),
            _buildTracker("Streak"),
          ],
        ),
      ],
    );
  }
}
