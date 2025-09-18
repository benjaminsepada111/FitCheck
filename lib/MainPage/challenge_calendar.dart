import 'package:flutter/material.dart';
import 'create_challenge_sheet.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'daily_logs.dart';

class ChallengeCalendar extends StatefulWidget {
  final Challenge? currentChallenge;
  final Function(Challenge) onChallengeCreated;
  final VoidCallback onChallengeEnded;

  const ChallengeCalendar({
    super.key,
    this.currentChallenge,
    required this.onChallengeCreated,
    required this.onChallengeEnded,
  });

  @override
  State<ChallengeCalendar> createState() => _ChallengeCalendarState();
}

class _ChallengeCalendarState extends State<ChallengeCalendar> {
  DateTime currentMonth = DateTime(2025, 1); // January 2025

  @override
  void initState() {
    super.initState();
    // If there's an active challenge when the widget loads, navigate to its start month
    if (widget.currentChallenge != null) {
      currentMonth = DateTime(
        widget.currentChallenge!.startDate.year,
        widget.currentChallenge!.startDate.month,
      );
    }
  }

  @override
  void didUpdateWidget(ChallengeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If challenge changed and we have a new one, navigate to its start month
    if (widget.currentChallenge != null &&
        oldWidget.currentChallenge != widget.currentChallenge) {
      setState(() {
        currentMonth = DateTime(
          widget.currentChallenge!.startDate.year,
          widget.currentChallenge!.startDate.month,
        );
      });
    }
  }

  // Method to handle challenge creation
  void _onChallengeCreated(Challenge challenge) {
    // Call the parent's callback to update the main state
    widget.onChallengeCreated(challenge);

    // Navigate to the start date's month
    setState(() {
      currentMonth =
          DateTime(challenge.startDate.year, challenge.startDate.month);
    });
  }

  // Method to check if a date is within the challenge period
  bool _isDateInChallenge(int day) {
    if (widget.currentChallenge == null) return false;

    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.isAfter(
        widget.currentChallenge!.startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(
            widget.currentChallenge!.endDate.add(const Duration(days: 1)));
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
    if (widget.currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == widget.currentChallenge!.startDate.year &&
        date.month == widget.currentChallenge!.startDate.month &&
        date.day == widget.currentChallenge!.startDate.day;
  }

  // Check if this day is the challenge end date
  bool _isEndDate(int day) {
    if (widget.currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == widget.currentChallenge!.endDate.year &&
        date.month == widget.currentChallenge!.endDate.month &&
        date.day == widget.currentChallenge!.endDate.day;
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

  // Get the first day of the month and build calendar grid dynamically
  List<Widget> _buildCalendarDays() {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday %
        7; // Convert to 0-6 where 0 is Sunday

    List<Widget> days = [];

    // Add previous month's trailing days
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    final prevMonthLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0)
        .day;

    for (int i = startWeekday - 1; i >= 0; i--) {
      days.add(_buildDateCell('${prevMonthLastDay - i}', isOtherMonth: true));
    }

    // Add current month days
    for (int day = 1; day <= lastDay.day; day++) {
      days.add(_buildDateCell('$day', day: day));
    }

    // Add next month's leading days to fill the grid
    int remainingDays = 42 - days.length; // 6 rows * 7 days = 42
    if (remainingDays > 7)
      remainingDays = 42 - days.length; // Ensure we don't add too many

    for (int day = 1; day <= remainingDays && days.length < 42; day++) {
      days.add(_buildDateCell('$day', isOtherMonth: true));
    }

    return days;
  }

  // Build weeks from the days list
  List<Widget> _buildWeeks(List<Widget> days) {
    List<Widget> weeks = [];

    // Handle the special case for the "Start A Challenge" button
    if (widget.currentChallenge == null && days.length >= 14) {
      // First two weeks
      weeks.add(_buildWeekRow(days.sublist(0, 7)));
      weeks.add(_buildWeekRow(days.sublist(7, 14)));

      // Third week with button (if we have enough days and it's appropriate to show)
      if (days.length >= 21) {
        List<Widget> thirdWeek = days.sublist(14, 21);
        // Replace middle days with the button
        weeks.add(Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            thirdWeek[0],
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
                      builder: (context) =>
                          CreateChallengeSheet(
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
            thirdWeek[6],
          ],
        ));

        // Add remaining weeks
        for (int i = 21; i < days.length; i += 7) {
          int endIndex = (i + 7 < days.length) ? i + 7 : days.length;
          if (endIndex - i == 7) {
            weeks.add(_buildWeekRow(days.sublist(i, endIndex)));
          }
        }
      }
    } else {
      // Normal calendar layout when challenge is active
      for (int i = 0; i < days.length; i += 7) {
        int endIndex = (i + 7 < days.length) ? i + 7 : days.length;
        if (endIndex - i == 7) {
          weeks.add(_buildWeekRow(days.sublist(i, endIndex)));
        }
      }
    }

    return weeks;
  }

  void _handleEndChallenge() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'End Challenge',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to end this challenge?'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700],
                          size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will reset your progress and stop tracking.',
                          style: TextStyle(fontSize: 12),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onChallengeEnded();
                  Navigator.pop(context);

                  // Show confirmation snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Challenge ended successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Challenge'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = _buildCalendarDays();
    final weeks = _buildWeeks(calendarDays);

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
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                        widget.currentChallenge == null
                            ? "No Challenge Started"
                            : widget.currentChallenge!.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.currentChallenge == null
                              ? Colors.grey
                              : AppColors.secondary,
                          fontWeight: widget.currentChallenge == null
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(true),
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Days of week header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((day) =>
                    SizedBox(
                      width: 32,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: widget.currentChallenge != null ? Colors
                              .black87 : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar grid - dynamically built weeks
              Column(children: weeks),

              // Challenge info section (show when challenge is active)
              if (widget.currentChallenge != null) ...[
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
                          const Text(
                            'Active Challenge',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _handleEndChallenge,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.more_horiz,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Goals: ${widget.currentChallenge!
                            .dailyCalorieGoal} cal • ${widget.currentChallenge!
                            .dailyWaterGoal} glasses',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.currentChallenge!.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.currentChallenge!.notes,
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

  void _navigateToDailyLog(DateTime selectedDate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DailyLogsPage(
              selectedDate: selectedDate,
              challenge: widget.currentChallenge,
            ),
      ),
    );
  }

  Widget _buildDateCell(String date, {bool isOtherMonth = false, int? day}) {
    final isInChallenge = day != null ? _isDateInChallenge(day) : false;
    final isStart = day != null ? _isStartDate(day) : false;
    final isEnd = day != null ? _isEndDate(day) : false;
    final isCurrentDay = day != null ? _isToday(day) : false;
    final isClickable = isInChallenge || isStart || isEnd;

    Color backgroundColor;
    Color textColor;
    BorderRadius borderRadius = BorderRadius.circular(8);

    if (isStart || isEnd) {
      // Start and end dates get special highlighting
      backgroundColor = AppColors.secondary;
      textColor = Colors.white;
    } else if (isInChallenge) {
      // Dates within challenge period get lighter highlighting
      backgroundColor = AppColors.secondary.withOpacity(0.3);
      textColor = AppColors.secondary;
    } else if (isCurrentDay) {
      // Today's date (when not part of challenge)
      backgroundColor = Colors.red.shade300;
      textColor = Colors.white;
    } else if (isOtherMonth) {
      // Other month dates - visibility depends on challenge state
      backgroundColor = Colors.grey.shade200.withOpacity(0.3);
      textColor =
      widget.currentChallenge != null ? Colors.grey.shade500 : Colors.grey
          .shade400.withOpacity(0.6);
    } else {
      // Regular dates in current month - clearer only when challenge is active
      backgroundColor = Colors.grey.shade200.withOpacity(0.3);
      textColor =
      widget.currentChallenge != null ? Colors.black87 : Colors.black
          .withOpacity(0.2);
    }

    Widget dateWidget = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        // Add border for current day if it's not a challenge date
        border: isCurrentDay && !isInChallenge && !isStart && !isEnd
            ? Border.all(color: AppColors.secondary, width: 2)
            : null,
        // Add subtle shadow for clickable dates
        boxShadow: isClickable ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ] : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              date,
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isStart || isEnd || isCurrentDay)
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          // Add small indicator for clickable challenge days
          if (isClickable && day != null)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isStart || isEnd ? Colors.white : AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      width: 32,
      height: 32,
      child: isClickable && day != null
          ? InkWell(
        onTap: () {
          final selectedDate = DateTime(
              currentMonth.year, currentMonth.month, day);

          // Show feedback for tap
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Opening daily log for ${_formatSelectedDate(selectedDate)}'
              ),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          _navigateToDailyLog(selectedDate);
        },
        borderRadius: borderRadius,
        splashColor: AppColors.secondary.withOpacity(0.3),
        highlightColor: AppColors.secondary.withOpacity(0.1),
        child: dateWidget,
      )
          : dateWidget,
    );
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}