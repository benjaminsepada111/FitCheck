import 'package:flutter/material.dart';
import '../color/colors.dart';
import '../services/simple_weekly_summary_service.dart';
import '../models/challenge.dart';
import '../widgets/fitcheck_loader.dart';

class SimpleWeeklySummaryCard extends StatefulWidget {
  final Challenge challenge;
  final int weekNumber;

  const SimpleWeeklySummaryCard({
    super.key,
    required this.challenge,
    required this.weekNumber,
  });

  @override
  State<SimpleWeeklySummaryCard> createState() => _SimpleWeeklySummaryCardState();
}

class _SimpleWeeklySummaryCardState extends State<SimpleWeeklySummaryCard> {
  WeeklySummaryData? _summaryData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void didUpdateWidget(SimpleWeeklySummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekNumber != widget.weekNumber) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await SimpleWeeklySummaryService.getWeeklySummary(
        challenge: widget.challenge,
        weekNumber: widget.weekNumber,
      );

      if (mounted) {
        setState(() {
          _summaryData = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load summary';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_error != null || _summaryData == null) {
      return _buildErrorCard();
    }

    return _buildSummaryCard(_summaryData!);
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const FitCheckLoader(),
            const SizedBox(height: 16),
            Text(
              'Loading weekly summary...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load summary',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadSummary,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(WeeklySummaryData data) {
    final quote = SimpleTipsService.getMotivationalQuote();
    final congratulations = SimpleTipsService.getCongratulationsMessage(data.weekNumber);
    final encouragement = SimpleTipsService.getEncouragementMessage(data);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.insights,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Week Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Congratulations Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                congratulations,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Real Data Stats
            // Days Missed
            _buildStatRow(
              'Days Missed',
              '${data.daysMissed}',
              Icons.calendar_today,
              data.daysMissed == 0 ? Colors.green.shade600 : Colors.orange.shade600,
            ),
            const SizedBox(height: 12),

            // Total Calories Consumed (strictly within that week)
            _buildStatRow(
              'Total Calories Consumed',
              '${data.totalCaloriesConsumed}',
              Icons.restaurant,
              Colors.orange.shade600,
            ),
            const SizedBox(height: 12),

            // Total Calories Burned (strictly within that week)
            _buildStatRow(
              'Total Calories Burned',
              '${data.totalCaloriesBurned}',
              Icons.local_fire_department,
              Colors.red.shade600,
            ),

            const SizedBox(height: 20),

            // Encouragement Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Text(
                encouragement,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Motivational Quote
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.format_quote,
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quote,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

