import 'package:flutter/material.dart';
import 'create_challenge_sheet.dart';
import 'package:capstone_project/color/colors.dart';

class ChallengeCalendar extends StatelessWidget {
  const ChallengeCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Challenge Calendar",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header with navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      // TODO: Previous month logic
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Column(
                    children: [
                      const Text(
                        "January 2025",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Text(
                        "No Challenge Started",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Next month logic
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Days of week header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((day) => SizedBox(
                  width: 32,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar grid
              Column(
                children: [
                  // Week 1
                  _buildWeekRow([
                    _buildDateCell('29', isOtherMonth: true),
                    _buildDateCell('30', isOtherMonth: true),
                    _buildDateCell('31', isOtherMonth: true),
                    _buildDateCell('1'),
                    _buildDateCell('2'),
                    _buildDateCell('3'),
                    _buildDateCell('4'),
                  ]),

                  // Week 2
                  _buildWeekRow([
                    _buildDateCell('5'),
                    _buildDateCell('6'),
                    _buildDateCell('7'),
                    _buildDateCell('8'),
                    _buildDateCell('9'),
                    _buildDateCell('10'),
                    _buildDateCell('11'),
                  ]),

                  // Week 3 with button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDateCell('12'),
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true, // makes full height & slide-up effect
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => const CreateChallengeSheet(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Start A Challenge",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),

                        ),
                      ),
                      _buildDateCell('18'),
                    ],
                  ),

                  // Week 4
                  _buildWeekRow([
                    _buildDateCell('19'),
                    _buildDateCell('20'),
                    _buildDateCell('21'),
                    _buildDateCell('22'),
                    _buildDateCell('23'),
                    _buildDateCell('24'),
                    _buildDateCell('25'),
                  ]),

                  // Week 5
                  _buildWeekRow([
                    _buildDateCell('26'),
                    _buildDateCell('27'),
                    _buildDateCell('28'),
                    _buildDateCell('29'),
                    _buildDateCell('30'),
                    _buildDateCell('31'),
                    _buildDateCell('01', isOtherMonth: true),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      ),
    );
  }
  Widget _buildDateCell(String date, {bool isOtherMonth = false}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(0.3), // light faded background
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            date,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isOtherMonth
                  ? Colors.grey.shade400.withOpacity(0.6) // very faint for prev/next month
                  : Colors.black.withOpacity(0.2),       // faded black for current month
            ),
          ),
        ),
      ),
    );
  }
}
