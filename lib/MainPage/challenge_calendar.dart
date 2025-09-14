import 'package:flutter/material.dart';
import 'create_challenge_sheet.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';

class ChallengeCalendar extends StatefulWidget {
  const ChallengeCalendar({super.key});

  @override
  State<ChallengeCalendar> createState() => _ChallengeCalendarState();
}

class _ChallengeCalendarState extends State<ChallengeCalendar> {
  Challenge? currentChallenge;
  DateTime currentMonth = DateTime(2025, 1); // January 2025

  // Method to handle challenge creation
  void _onChallengeCreated(Challenge challenge) {
    setState(() {
      currentChallenge = challenge;
    });
  }

  // Method to check if a date is within the challenge period
  bool _isDateInChallenge(int day) {
    if (currentChallenge == null) return false;

    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.isAfter(currentChallenge!.startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(currentChallenge!.endDate.add(const Duration(days: 1)));
  }

  // Method to check if a date is today
  bool _isToday(int day) {
    final today = DateTime.now();
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  // Check if this day is the challenge start date
  bool _isStartDate(int day) {
    if (currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == currentChallenge!.startDate.year &&
        date.month == currentChallenge!.startDate.month &&
        date.day == currentChallenge!.startDate.day;
  }

  // Check if this day is the challenge end date
  bool _isEndDate(int day) {
    if (currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == currentChallenge!.endDate.year &&
        date.month == currentChallenge!.endDate.month &&
        date.day == currentChallenge!.endDate.day;
  }


  // Get month name
  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
  }

  // Navigate to previous/next month
  void _changeMonth(bool isNext) {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + (isNext ? 1 : -1),
      );
    });
  }

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
                    onPressed: () => _changeMonth(false),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Column(
                    children: [
                      Text(
                        "${_getMonthName(currentMonth)} ${currentMonth.year}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        currentChallenge == null
                            ? "No Challenge Started"
                            : currentChallenge!.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: currentChallenge == null
                              ? Colors.grey
                              : AppColors.secondary,
                          fontWeight: currentChallenge == null
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(true),
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
                    _buildDateCell('1', day: 1),
                    _buildDateCell('2', day: 2),
                    _buildDateCell('3', day: 3),
                    _buildDateCell('4', day: 4),
                  ]),

                  // Week 2
                  _buildWeekRow([
                    _buildDateCell('5', day: 5),
                    _buildDateCell('6', day: 6),
                    _buildDateCell('7', day: 7),
                    _buildDateCell('8', day: 8),
                    _buildDateCell('9', day: 9),
                    _buildDateCell('10', day: 10),
                    _buildDateCell('11', day: 11),
                  ]),

                  // Week 3 with button (only show if no active challenge)
                  currentChallenge == null
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDateCell('12', day: 12),
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) => CreateChallengeSheet(
                                  onChallengeCreated: _onChallengeCreated,
                                ),
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
                      _buildDateCell('18', day: 18),
                    ],
                  )
                      : _buildWeekRow([
                    _buildDateCell('12', day: 12),
                    _buildDateCell('13', day: 13),
                    _buildDateCell('14', day: 14),
                    _buildDateCell('15', day: 15),
                    _buildDateCell('16', day: 16),
                    _buildDateCell('17', day: 17),
                    _buildDateCell('18', day: 18),
                  ]),

                  // Week 4
                  _buildWeekRow([
                    _buildDateCell('19', day: 19),
                    _buildDateCell('20', day: 20),
                    _buildDateCell('21', day: 21),
                    _buildDateCell('22', day: 22),
                    _buildDateCell('23', day: 23),
                    _buildDateCell('24', day: 24),
                    _buildDateCell('25', day: 25),
                  ]),

                  // Week 5
                  _buildWeekRow([
                    _buildDateCell('26', day: 26),
                    _buildDateCell('27', day: 27),
                    _buildDateCell('28', day: 28),
                    _buildDateCell('29', day: 29),
                    _buildDateCell('30', day: 30),
                    _buildDateCell('31', day: 31),
                    _buildDateCell('01', isOtherMonth: true),
                  ]),
                ],
              ),

              // Challenge info section (show when challenge is active)
              if (currentChallenge != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active Challenge',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Show challenge details or options
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Challenge Options'),
                                  content: const Text('Would you like to end this challenge?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          currentChallenge = null;
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'End Challenge',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Icon(
                              Icons.more_horiz,
                              color: AppColors.secondary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Goals: ${currentChallenge!.dailyCalorieGoal} cal • ${currentChallenge!.dailyWaterGoal} glasses',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (currentChallenge!.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentChallenge!.notes,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  Widget _buildDateCell(String date, {bool isOtherMonth = false, int? day}) {
    final isInChallenge = day != null ? _isDateInChallenge(day) : false;
    final isStart = day != null ? _isStartDate(day) : false;
    final isEnd = day != null ? _isEndDate(day) : false;
    final isCurrentDay = day != null ? _isToday(day) : false;

    Color backgroundColor;
    Color textColor;
    BorderRadius borderRadius = BorderRadius.circular(8);

    if (isStart || isEnd) {
      // Start and end dates get special highlighting (like in your image)
      backgroundColor = AppColors.secondary;
      textColor = Colors.white;
    } else if (isInChallenge) {
      // Dates within challenge period get lighter highlighting
      backgroundColor = AppColors.secondary.withOpacity(0.3);
      textColor = AppColors.secondary;
    } else if (isCurrentDay) {
      // Today's date (when not part of challenge)
      backgroundColor = Colors.grey.shade300;
      textColor = Colors.black87;
    } else if (isOtherMonth) {
      // Other month dates
      backgroundColor = Colors.grey.shade200.withOpacity(0.3);
      textColor = Colors.grey.shade400.withOpacity(0.6);
    } else {
      // Regular dates in current month
      backgroundColor = Colors.grey.shade200.withOpacity(0.3);
      textColor = Colors.black.withOpacity(0.2);
    }

    return SizedBox(
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          // Add border for current day if it's not a challenge date
          border: isCurrentDay && !isInChallenge && !isStart && !isEnd
              ? Border.all(color: AppColors.secondary, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            date,
            style: TextStyle(
              fontSize: 14,
              fontWeight: (isStart || isEnd || isCurrentDay) ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}