import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/food_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeSummaryPage extends StatefulWidget {
  final Map<String, dynamic> challenge;

  const ChallengeSummaryPage({super.key, required this.challenge});

  @override
  State<ChallengeSummaryPage> createState() => _ChallengeSummaryPageState();
}

class _ChallengeSummaryPageState extends State<ChallengeSummaryPage> {
  bool isMonthlySelected = false; // Default view: Weekly Summary (false = Weekly, true = Overall)
  int _totalWaterConsumed = 0;
  bool _isLoading = true;
  List<FlSpot> _dailyCalorieDataPoints = [];
  List<FlSpot> _weeklyCalorieDataPoints = [];
  List<FlSpot> _monthlyCalorieDataPoints = [];
  Map<int, List<FlSpot>> _weeklyDailyData = {}; // Data for each week
  List<String> _monthKeys = []; // Month keys for label display
  double _minDailyCalories = 0;
  double _maxDailyCalories = 2500;
  double _minWeeklyCalories = 0;
  double _maxWeeklyCalories = 2500;
  double _minMonthlyCalories = 0;
  double _maxMonthlyCalories = 2500;
  int _totalDays = 0;
  int _totalWeeks = 0;
  int _totalMonths = 0;
  int _currentWeek = 1;
  int _currentPeriod = 1; // For overall view navigation
  bool _useMonthsForOverall = false;

  @override
  void initState() {
    super.initState();
    _loadChallengeData();
  }

  Future<void> _loadChallengeData() async {
    setState(() => _isLoading = true);

    try {
      final challengeId = widget.challenge['challengeId'] as String?;
      if (challengeId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final startDate = widget.challenge['startDate'] as DateTime;
      final endDate = widget.challenge['endDate'] as DateTime;

      // Calculate total days
      final totalDays = endDate.difference(startDate).inDays + 1;

      // Calculate total calories consumed and build data points
      int totalWater = 0;
      List<FlSpot> dataPoints = [];
      List<double> calorieValues = [];

      // Loop through each day of the challenge
      int dayIndex = 0;
      for (DateTime date = startDate;
           date.isBefore(endDate.add(const Duration(days: 1)));
           date = date.add(const Duration(days: 1))) {

        // Get calories for this day
        final dailyCalories = await FoodLogService.getDailyCalories(date, challengeId: challengeId);

        // Add data point for chart (x = day number, y = calories)
        dayIndex++;
        dataPoints.add(FlSpot(dayIndex.toDouble(), dailyCalories));
        calorieValues.add(dailyCalories);

        // Get water for this day
        final dailyWater = await _getWaterIntakeForDate(date);
        totalWater += dailyWater;
      }

      // Calculate min and max for chart scaling
      double minCal = 0;
      double maxCal = 2500;
      if (calorieValues.isNotEmpty) {
        minCal = calorieValues.reduce((a, b) => a < b ? a : b);
        maxCal = calorieValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxCal - minCal) * 0.2;
        minCal = (minCal - padding).clamp(0, double.infinity);
        maxCal = maxCal + padding;
      }

      // Calculate total weeks based on challenge duration (not just data available)
      final challengeDuration = endDate.difference(startDate).inDays + 1;
      final totalWeeksInChallenge = (challengeDuration / 7).ceil();
      final now = DateTime.now();

      // Calculate weekly data (for Overall view - shows average per week)
      List<FlSpot> weeklyDataPoints = [];
      List<double> weeklyCalorieValues = [];
      int weekIndex = 0;

      // Also store daily data per week (for Weekly Summary view)
      Map<int, List<FlSpot>> weeklyDailyData = {};

      // Create weekly data for all weeks
      for (int weekNum = 1; weekNum <= totalWeeksInChallenge; weekNum++) {
        weekIndex = weekNum;

        // Calculate which days belong to this week
        int startDayIndex = (weekNum - 1) * 7;
        int endDayIndex = startDayIndex + 6;

        // Check if this week is completed (all 7 days have passed)
        final weekEndDate = startDate.add(Duration(days: endDayIndex));
        final isWeekCompleted = now.isAfter(weekEndDate);

        double weeklyCalories = 0;
        int daysInWeek = 0;
        List<FlSpot> weekDays = [];

        // Collect data for this week (only if data exists)
        for (int dayIndex = startDayIndex; dayIndex <= endDayIndex && dayIndex < dataPoints.length; dayIndex++) {
          weeklyCalories += dataPoints[dayIndex].y;
          daysInWeek++;
          // Store daily data for this week (day 1-7 of the week)
          weekDays.add(FlSpot((daysInWeek).toDouble(), dataPoints[dayIndex].y));
        }

        // Store weekly daily data for Weekly Summary view (all weeks)
        weeklyDailyData[weekIndex] = weekDays;

        // For Overall view: only include COMPLETED weeks with full 7 days of data
        if (isWeekCompleted && daysInWeek == 7) {
          double avgCalories = weeklyCalories / 7;
          weeklyDataPoints.add(FlSpot(weekNum.toDouble(), avgCalories));
          weeklyCalorieValues.add(avgCalories);
        }
      }

      // Calculate min and max for weekly chart scaling
      double minWeeklyCal = 0;
      double maxWeeklyCal = 2500;
      if (weeklyCalorieValues.isNotEmpty) {
        minWeeklyCal = weeklyCalorieValues.reduce((a, b) => a < b ? a : b);
        maxWeeklyCal = weeklyCalorieValues.reduce((a, b) => a > b ? a : b);

        // Add padding to min/max
        final padding = (maxWeeklyCal - minWeeklyCal) * 0.2;
        minWeeklyCal = (minWeeklyCal - padding).clamp(0, double.infinity);
        maxWeeklyCal = maxWeeklyCal + padding;
      }

      // Calculate monthly data if challenge is >= 3 months
      List<FlSpot> monthlyDataPoints = [];
      List<double> monthlyCalorieValues = [];
      List<String> monthKeys = []; // Store month keys for label display
      int monthIndex = 0;
      bool useMonths = totalDays >= 90; // 3+ months

      if (useMonths) {
        // Group by actual calendar months
        Map<String, List<double>> monthlyData = {};
        List<String> orderedMonthKeys = [];

        DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
        final endMonth = DateTime(endDate.year, endDate.month, 1);

        // Create ordered list of months
        while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
          String monthKey = '${currentMonth.year}-${currentMonth.month}';
          orderedMonthKeys.add(monthKey);
          monthlyData[monthKey] = [];
          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
        }

        // Fill in the data
        for (DateTime date = startDate;
             date.isBefore(endDate.add(const Duration(days: 1)));
             date = date.add(const Duration(days: 1))) {

          String monthKey = '${date.year}-${date.month}';

          // Find the corresponding calorie data
          int daysSinceStart = date.difference(startDate).inDays;
          if (daysSinceStart < calorieValues.length && monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey]!.add(calorieValues[daysSinceStart]);
          }
        }

        // Calculate averages for each month in order
        monthIndex = 0;
        for (String key in orderedMonthKeys) {
          monthIndex++;
          monthKeys.add(key);
          double avgCalories = monthlyData[key]!.isEmpty
            ? 0
            : monthlyData[key]!.reduce((a, b) => a + b) / monthlyData[key]!.length;
          monthlyDataPoints.add(FlSpot(monthIndex.toDouble(), avgCalories));
          monthlyCalorieValues.add(avgCalories);
        }
      }

      // Calculate min and max for monthly chart scaling
      double minMonthlyCal = 0;
      double maxMonthlyCal = 2500;
      if (monthlyCalorieValues.isNotEmpty) {
        minMonthlyCal = monthlyCalorieValues.reduce((a, b) => a < b ? a : b);
        maxMonthlyCal = monthlyCalorieValues.reduce((a, b) => a > b ? a : b);

        final padding = (maxMonthlyCal - minMonthlyCal) * 0.2;
        minMonthlyCal = (minMonthlyCal - padding).clamp(0, double.infinity);
        maxMonthlyCal = maxMonthlyCal + padding;
      }

      setState(() {
        _totalWaterConsumed = totalWater;
        _dailyCalorieDataPoints = dataPoints;
        _weeklyCalorieDataPoints = weeklyDataPoints;
        _monthlyCalorieDataPoints = monthlyDataPoints;
        _weeklyDailyData = weeklyDailyData;
        _monthKeys = monthKeys;
        _minDailyCalories = minCal;
        _maxDailyCalories = maxCal;
        _minWeeklyCalories = minWeeklyCal;
        _maxWeeklyCalories = maxWeeklyCal;
        _minMonthlyCalories = minMonthlyCal;
        _maxMonthlyCalories = maxMonthlyCal;
        _totalDays = totalDays;
        _totalWeeks = weekIndex;
        _totalMonths = monthIndex;
        _useMonthsForOverall = useMonths;
        _currentWeek = 1;
        _currentPeriod = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getWaterIntakeForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = 'water_intake_${_formatDateKey(date)}';
      return prefs.getInt(dateKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateDuration(Map<String, dynamic> challenge) {
    if (challenge['startDate'] == null || challenge['endDate'] == null) return 0;
    final startDate = challenge['startDate'] as DateTime;
    final endDate = challenge['endDate'] as DateTime;
    return endDate.difference(startDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Challenge History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildChallengeCard(widget.challenge),
            const SizedBox(height: 20),
            _buildSummaryButtons(),
            const SizedBox(height: 12),
            _buildPeriodNavigation(),
            const SizedBox(height: 20),
            _buildCalorieProgressChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    challenge['title'] ?? 'Challenge',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    challenge['status'] ?? 'Completed',
                    style: TextStyle(
                      color: AppColors.secondary[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  challenge['dateRange'] ?? 'No dates',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress
            const Text(
              'Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (challenge['progress'] ?? 100) / 100.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${challenge['progress'] ?? 100}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats
            _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.local_fire_department,
                      label: 'Daily Calorie',
                      value: '${widget.challenge['dailyCalorieGoal'] ?? 'N/A'}',
                      color: AppColors.secondary,
                    ),
                    _buildStatItem(
                      icon: Icons.local_drink,
                      label: 'Total Water',
                      value: '$_totalWaterConsumed glasses',
                      color: AppColors.secondary,
                    ),
                    _buildStatItem(
                      icon: Icons.access_time,
                      label: 'Duration',
                      value: '${_calculateDuration(widget.challenge)} Days',
                      color: AppColors.secondary,
                    ),
                  ],
                ),

            const SizedBox(height: 24),

            // Notes
            if (challenge['notes'] != null && (challenge['notes'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondary.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge['notes'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSummaryButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isMonthlySelected = false;
                _currentWeek = 1; // Reset to week 1 when switching
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !isMonthlySelected ? AppColors.secondary : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Weekly Summary',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: !isMonthlySelected ? Colors.white : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isMonthlySelected = true;
                _currentPeriod = 1; // Reset to period 1 when switching
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isMonthlySelected ? AppColors.secondary : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Overall',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMonthlySelected ? Colors.white : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodNavigation() {
    if (_isLoading) return const SizedBox.shrink();

    final isWeekly = !isMonthlySelected;

    if (isWeekly) {
      // Weekly Summary: show week selection buttons
      if (_totalWeeks <= 1) return const SizedBox.shrink();

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_totalWeeks, (index) {
          final weekNumber = index + 1;
          final isSelected = weekNumber == _currentWeek;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == _totalWeeks - 1 ? 0 : 4,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentWeek = weekNumber;
                  });
                },
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.secondary : AppColors.secondary.shade200,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      weekNumber.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
    } else {
      // Overall: no navigation needed for overall view showing all data
      return const SizedBox.shrink();
    }
  }


  Widget _buildCalorieProgressChart() {
    // Show loading or empty state
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.shade200),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Determine which data to show based on selection
    // Weekly Summary = daily data for a specific week
    // Overall = weekly or monthly data for the entire challenge
    final isWeekly = !isMonthlySelected;

    List<FlSpot> dataPoints;
    double minCalories;
    double maxCalories;
    int totalPeriods;
    String periodLabel;

    if (isWeekly) {
      // Weekly Summary: show daily data for current week
      dataPoints = _weeklyDailyData[_currentWeek] ?? [];
      minCalories = _minDailyCalories;
      maxCalories = _maxDailyCalories;
      // Show all 7 days on x-axis even if only partial data
      totalPeriods = 7;
      periodLabel = 'DAY';
    } else {
      // Overall: show weekly or monthly data
      if (_useMonthsForOverall) {
        dataPoints = _monthlyCalorieDataPoints;
        minCalories = _minMonthlyCalories;
        maxCalories = _maxMonthlyCalories;
        totalPeriods = _totalMonths;
        periodLabel = 'WEEK';
      } else {
        dataPoints = _weeklyCalorieDataPoints;
        minCalories = _minWeeklyCalories;
        maxCalories = _maxWeeklyCalories;
        totalPeriods = _totalWeeks;
        periodLabel = 'WEEK';
      }
    }

    if (dataPoints.isEmpty) {
      // For Weekly Summary with no data: show empty state
      if (isWeekly) {
        final startDate = widget.challenge['startDate'] as DateTime;
        final endDate = widget.challenge['endDate'] as DateTime;
        final weekStartDay = (_currentWeek - 1) * 7;
        final weekStart = startDate.add(Duration(days: weekStartDay));
        final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
        final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
        String dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CALORIE PROGRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  dateRange.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No data for Week $_currentWeek yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data will appear as you log calories',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      }
      // For Overall view with no data: still show the chart with week numbers
      // (fall through to show chart with empty data points)
    }

    // Format date range based on view
    final startDate = widget.challenge['startDate'] as DateTime;
    final endDate = widget.challenge['endDate'] as DateTime;
    String dateRange;

    if (isWeekly) {
      // Show date range for current week
      final weekStartDay = (_currentWeek - 1) * 7;
      final weekStart = startDate.add(Duration(days: weekStartDay));
      final weekEnd = startDate.add(Duration(days: weekStartDay + 6));
      final actualWeekEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
      dateRange = '${_formatDateShort(weekStart)} - ${_formatDateShort(actualWeekEnd)}';
    } else {
      // Show full date range
      dateRange = '${_formatDateShort(startDate)} - ${_formatDateShort(endDate)}';
    }

    // Calculate interval for y-axis
    final range = maxCalories - minCalories;
    final interval = (range / 4).roundToDouble().clamp(100.0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CALORIE PROGRESS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            Text(
              dateRange.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Only show labels for integer values to avoid duplicates
                          if (value != value.roundToDouble()) {
                            return const Text('');
                          }

                          final period = value.toInt();
                          if (period >= 1 && period <= totalPeriods) {
                            // Show month names if using monthly view
                            if (!isWeekly && _useMonthsForOverall) {
                              // Get month from stored keys
                              if (period - 1 < _monthKeys.length) {
                                final monthKey = _monthKeys[period - 1];
                                final parts = monthKey.split('-');
                                if (parts.length == 2) {
                                  final month = int.parse(parts[1]);
                                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      months[month - 1],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                              }
                            } else {
                              // Show numbers for weekly or daily view
                              // For weekly/daily: show all numbers if <= 10 periods, otherwise show first and last
                              if (totalPeriods <= 10) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    period.toString(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              } else if (period == 1 || period == totalPeriods) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    period.toString(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1,
                  maxX: totalPeriods.toDouble(),
                  minY: minCalories,
                  maxY: maxCalories,
                  lineBarsData: dataPoints.isEmpty
                      ? []
                      : [
                          LineChartBarData(
                            spots: dataPoints,
                            isCurved: false,
                            color: AppColors.secondary,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.secondary,
                                  strokeColor: Colors.white,
                                  strokeWidth: 2,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                    ),
                  ),
                  // Transparent overlay when no data in Overall view
                  if (!isWeekly && dataPoints.isEmpty)
                    Container(
                      color: Colors.white.withValues(alpha: 0.85),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No completed weeks yet',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Data will appear after a full week',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                periodLabel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}