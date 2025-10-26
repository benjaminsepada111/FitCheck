import 'package:flutter/material.dart';
import 'create_challenge_sheet.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import '../app_text_styles.dart';
import 'daily_logs.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:capstone_project/services/milestone_service.dart';
import 'package:capstone_project/services/user_achievement_service.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  DateTime currentMonth = DateTime(2025, 1);
  Map<String, bool> _dayCompletionStatus = {};
  bool _isLoadingCompletions = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentChallenge != null) {
      currentMonth = DateTime(
        widget.currentChallenge!.startDate.year,
        widget.currentChallenge!.startDate.month,
      );
      _loadMonthCompletions();
    }
  }

  @override
  void didUpdateWidget(ChallengeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentChallenge != null &&
        oldWidget.currentChallenge != widget.currentChallenge) {
      setState(() {
        currentMonth = DateTime(
          widget.currentChallenge!.startDate.year,
          widget.currentChallenge!.startDate.month,
        );
      });
      _loadMonthCompletions();
    }
  }

  // Load completion status for all days in the current month
  Future<void> _loadMonthCompletions() async {
    if (widget.currentChallenge == null) return;

    setState(() => _isLoadingCompletions = true);

    try {
      final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
      final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

      Map<String, bool> completions = {};

      // Check each day in the month
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(currentMonth.year, currentMonth.month, day);

        // Only check days within challenge period
        if (_isDateInChallenge(day)) {
          final isComplete = await _checkDayCompletion(date);
          completions[_getDateKey(date)] = isComplete;
        }
      }

      if (mounted) {
        setState(() {
          _dayCompletionStatus = completions;
          _isLoadingCompletions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCompletions = false);
      }
    }
  }

  // Check if a specific day is complete
  Future<bool> _checkDayCompletion(DateTime date) async {
    try {
      if (widget.currentChallenge == null) return false;

      // Check if there are any food logs
      final foodLogs = await FoodLogService.getFoodLogsForDate(date, challengeId: widget.currentChallenge!.id);
      final hasFood = foodLogs.isNotEmpty;

      // Check if there's water intake
      final prefs = await SharedPreferences.getInstance();
      final dateKey = 'water_intake_${_formatDateKey(date)}';
      final waterIntake = prefs.getInt(dateKey) ?? 0;
      final hasWater = waterIntake > 0;

      // Check if there are any milestones
      final allMilestones = await MilestoneService.getAllMilestones(challengeId: widget.currentChallenge!.id);
      final hasMilestone = allMilestones.any((m) =>
      m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day
      );

      // Day is complete if any activity was logged
      return hasFood || hasWater || hasMilestone;
    } catch (e) {
      return false;
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isDayComplete(int day) {
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return _dayCompletionStatus[_getDateKey(date)] ?? false;
  }

  void _onChallengeCreated(Challenge challenge) {
    widget.onChallengeCreated(challenge);
    setState(() {
      currentMonth = DateTime(challenge.startDate.year, challenge.startDate.month);
    });
    _loadMonthCompletions();
  }

  bool _isDateInChallenge(int day) {
    if (widget.currentChallenge == null) return false;

    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.isAfter(
        widget.currentChallenge!.startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(
            widget.currentChallenge!.endDate.add(const Duration(days: 1)));
  }

  bool _isToday(int day) {
    final today = DateTime.now();
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  bool _isStartDate(int day) {
    if (widget.currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == widget.currentChallenge!.startDate.year &&
        date.month == widget.currentChallenge!.startDate.month &&
        date.day == widget.currentChallenge!.startDate.day;
  }

  bool _isEndDate(int day) {
    if (widget.currentChallenge == null) return false;
    final date = DateTime(currentMonth.year, currentMonth.month, day);
    return date.year == widget.currentChallenge!.endDate.year &&
        date.month == widget.currentChallenge!.endDate.month &&
        date.day == widget.currentChallenge!.endDate.day;
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
  }

  void _changeMonth(bool isNext) {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + (isNext ? 1 : -1),
      );
    });
    _loadMonthCompletions();
  }

  List<Widget> _buildCalendarDays() {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

    List<Widget> days = [];

    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    final prevMonthLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    for (int i = startWeekday - 1; i >= 0; i--) {
      days.add(_buildDateCell('${prevMonthLastDay - i}', isOtherMonth: true));
    }

    for (int day = 1; day <= lastDay.day; day++) {
      days.add(_buildDateCell('$day', day: day));
    }

    int remainingDays = 35 - days.length;
    if (remainingDays > 0 && remainingDays <= 7) {
      for (int day = 1; day <= remainingDays && days.length < 35; day++) {
        days.add(_buildDateCell('$day', isOtherMonth: true));
      }
    }

    return days;
  }

  List<Widget> _buildWeeks(List<Widget> days) {
    List<Widget> weeks = [];

    if (widget.currentChallenge == null && days.length >= 14) {
      weeks.add(_buildWeekRow(days.sublist(0, 7)));
      weeks.add(_buildWeekRow(days.sublist(7, 14)));

      if (days.length >= 21) {
        List<Widget> thirdWeek = days.sublist(14, 21);
        weeks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: thirdWeek[0],
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
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
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: thirdWeek[6],
                ),
              ),
            ],
          ),
        ));

        for (int i = 21; i < days.length; i += 7) {
          int endIndex = (i + 7 < days.length) ? i + 7 : days.length;
          if (endIndex - i == 7) {
            weeks.add(_buildWeekRow(days.sublist(i, endIndex)));
          }
        }
      }
    } else {
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
      builder: (context) => AlertDialog(
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
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This will mark the challenge as complete and stop tracking.',
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Track challenge completion for achievements
              try {
                await UserAchievementService.trackChallengeCompletion();
              } catch (e) {
              }

              widget.onChallengeEnded();
              navigator.pop();

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Challenge completed successfully!'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 400 ? 16.0 : 12.0;
    final buttonSize = screenWidth > 400 ? 44.0 : 40.0;
    final iconSize = screenWidth > 400 ? 24.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Challenge Calendar",
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.secondary.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoadingCompletions
              ? SizedBox(
            height: 280,
            child: Center(
              child: FitCheckLoader(),
            ),
          )
              : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(false),
                    icon: Icon(Icons.chevron_left, size: iconSize),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size(buttonSize, buttonSize),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "${_getMonthName(currentMonth)} ${currentMonth.year}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
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
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(true),
                    icon: Icon(Icons.chevron_right, size: iconSize),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size(buttonSize, buttonSize),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((day) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.currentChallenge != null
                            ? Colors.black87
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Column(
                children: _buildWeeks(_buildCalendarDays()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children
            .map((child) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            child: child,
          ),
        ))
            .toList(),
      ),
    );
  }

  void _navigateToDailyLog(DateTime selectedDate) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLogsPage(
          selectedDate: selectedDate,
          challenge: widget.currentChallenge,
        ),
      ),
    );

    await _loadMonthCompletions();
  }

  Widget _buildDateCell(String date, {bool isOtherMonth = false, int? day}) {
    final isInChallenge = day != null ? _isDateInChallenge(day) : false;
    final isStart = day != null ? _isStartDate(day) : false;
    final isEnd = day != null ? _isEndDate(day) : false;
    final isCurrentDay = day != null ? _isToday(day) : false;
    final isComplete = day != null ? _isDayComplete(day) : false;
    final isClickable = isInChallenge || isStart || isEnd;

    // Determine if day is in the future
    final currentDate = day != null ? DateTime(currentMonth.year, currentMonth.month, day) : null;
    final today = DateTime.now();
    final isFuture = currentDate != null && currentDate.isAfter(DateTime(today.year, today.month, today.day));

    Color? backgroundColor;
    Color textColor = Colors.black;
    String? labelText;
    BorderRadius borderRadius = BorderRadius.circular(8);
    Border? border;
    IconData? icon;
    Gradient? gradient;

    // Priority order for visual states (using red color scheme):
    // 1. Start date - Deep red with gradient + flag icon
    // 2. End date - Deep red with gradient + finish flag icon
    // 3. Current day - Solid red with TODAY label + star icon
    // 4. Completed days - Solid red with checkmark
    // 5. Incomplete challenge days (missed) - Light red with warning icon
    // 6. Future challenge days - Very light red with circle outline
    // 7. Other month days - Grey
    // 8. Non-challenge days - Light grey

    if (isStart) {
      // START day - Deep red with gradient from bottom
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.secondary.shade600, AppColors.secondary.shade900],
      );
      textColor = Colors.white;
      labelText = 'START';
      icon = Icons.flag;
    } else if (isEnd) {
      // END day - Deep red with gradient from bottom + checkered flag
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.secondary.shade600, AppColors.secondary.shade900],
      );
      textColor = Colors.white;
      labelText = 'END';
      icon = Icons.sports_score;
    } else if (isCurrentDay && isInChallenge) {
      // TODAY within challenge - Solid red with star icon
      backgroundColor = AppColors.secondary;
      textColor = Colors.white;
      labelText = 'TODAY';
      icon = Icons.star;
    } else if (isComplete && isInChallenge) {
      // Completed day - Solid red with checkmark icon
      backgroundColor = AppColors.secondary;
      textColor = Colors.white;
      icon = Icons.check_circle;
    } else if (isInChallenge && !isFuture) {
      // Incomplete challenge day (missed) - Light red with warning
      backgroundColor = AppColors.secondary.shade50;
      textColor = AppColors.secondary.shade900;
      border = Border.all(color: AppColors.secondary.shade300, width: 1.5);
      icon = Icons.warning_amber_rounded;
    } else if (isInChallenge && isFuture) {
      // Future challenge day - Very light red with border
      backgroundColor = AppColors.secondary.shade50.withOpacity(0.3);
      textColor = AppColors.secondary.shade700;
      border = Border.all(color: AppColors.secondary.shade200, width: 1);
      icon = Icons.radio_button_unchecked;
    } else if (isCurrentDay) {
      // TODAY outside challenge - White with red border
      backgroundColor = Colors.white;
      textColor = AppColors.secondary;
      labelText = 'TODAY';
      border = Border.all(color: AppColors.secondary, width: 2);
    } else if (isOtherMonth) {
      // Other month days - Very light grey
      backgroundColor = Colors.grey.shade100.withOpacity(0.3);
      textColor = Colors.grey.shade400;
    } else {
      // Regular non-challenge days - Light grey
      backgroundColor = Colors.grey.shade50;
      textColor = widget.currentChallenge != null
          ? Colors.grey.shade600
          : Colors.grey.shade400;
    }

    Widget dateWidget = Container(
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border,
        boxShadow: isClickable
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              if (labelText != null) ...[
                const SizedBox(height: 2),
                Text(
                  labelText,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),

          // Icon indicator
          if (icon != null)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(
                icon,
                size: 12,
                color: textColor.withOpacity(0.9),
              ),
            ),
        ],
      ),
    );

    return AspectRatio(
      aspectRatio: 1.0,
      child: isClickable && day != null
          ? InkWell(
        onTap: () {
          final selectedDate =
          DateTime(currentMonth.year, currentMonth.month, day);
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}