import 'package:flutter/material.dart';
import 'package:capstone_project/color/colors.dart';

class Slide4 extends StatefulWidget {
  const Slide4({super.key});

  @override
  State<Slide4> createState() => _Slide4State();
}

class _Slide4State extends State<Slide4> {
  int selectedMonth = 1;
  int selectedDay = 1;
  int selectedYear = 2000;

  final List<int> months = List.generate(12, (i) => i + 1);
  final List<int> days = List.generate(31, (i) => i + 1);
  final List<int> years = List.generate(100, (i) => 2023 - i);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Birthdate",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter your date of birth.",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 30),

        // 📌 Pickers Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Month Picker
            buildPicker(
              label: "Month",
              values: months,
              selectedValue: selectedMonth,
              onSelected: (val) => setState(() => selectedMonth = val),
            ),
            const SizedBox(width: 20),

            // Day Picker
            buildPicker(
              label: "Day",
              values: days,
              selectedValue: selectedDay,
              onSelected: (val) => setState(() => selectedDay = val),
            ),
            const SizedBox(width: 20),

            // Year Picker
            buildPicker(
              label: "Year",
              values: years,
              selectedValue: selectedYear,
              onSelected: (val) => setState(() => selectedYear = val),
            ),
          ],
        ),
      ],
    );
  }

  // 🔧 Reusable Picker Widget
  Widget buildPicker({
    required String label,
    required List<int> values,
    required int selectedValue,
    required ValueChanged<int> onSelected,
  }) {
    final controller = FixedExtentScrollController(
      initialItem: values.indexOf(selectedValue),
    );

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ),
        const SizedBox(height: 10),
        Container(
          width: 90,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondary, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => onSelected(values[index]),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final isSelected = values[index] == selectedValue;
                return Center(
                  child: Text(
                    values[index].toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                );
              },
              childCount: values.length,
            ),
          ),
        ),
      ],
    );
  }
}
