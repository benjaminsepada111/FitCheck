import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/models/challenge.dart';
import 'challenge_summary_page.dart';

class ChallengeHistorySheet extends StatelessWidget {
  final List<Challenge> challengeHistory;
  final Function(Challenge)? onChallengeCreated;

  const ChallengeHistorySheet({
    super.key,
    required this.challengeHistory,
    this.onChallengeCreated,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isEmpty = challengeHistory.isEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Challenge History",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content based on whether challenges exist
              Expanded(
                child: isEmpty
                    ? _buildEmptyState(screenWidth, context)
                    : _buildChallengeList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(double screenWidth, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: screenWidth * 0.15,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Challenge History",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "You haven't completed any challenges yet. Start your first challenge to begin tracking your fitness journey!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: screenWidth * 0.7,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _triggerCreateChallenge(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Start Your First Challenge",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeList(ScrollController scrollController) {
    // Calculate real statistics from challenge data
    final totalChallenges = challengeHistory.length;
    final now = DateTime.now();
    final completedChallenges = challengeHistory
        .where((c) => c.endDate.isBefore(now))
        .length;
    final successRate = totalChallenges > 0
        ? ((completedChallenges / totalChallenges) * 100).round()
        : 0;

    return Column(
      children: [
        // Scrollable challenge list
        Expanded(
          child: challengeHistory.isEmpty
              ? const Center(
            child: Text(
              'No challenges found',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            controller: scrollController,
            itemCount: challengeHistory.length,
            itemBuilder: (context, index) {
              return _buildChallengeCard(challengeHistory[index], context);
            },
          ),
        ),

        // Fixed statistics at bottom
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatistic(
                totalChallenges.toString(),
                "Total Challenges",
                AppColors.secondary,
              ),
              _buildStatistic(
                completedChallenges.toString(),
                "Completed",
                Colors.green.shade600,
              ),
              _buildStatistic(
                "$successRate%",
                "Success Rate",
                Colors.blue.shade600,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(Challenge challenge, BuildContext context) {
    final now = DateTime.now();
    final isCompleted = challenge.endDate.isBefore(now);
    final isActive = challenge.startDate.isBefore(now) && challenge.endDate.isAfter(now);
    final progress = _calculateProgress(challenge);
    final daysTotal = challenge.endDate.difference(challenge.startDate).inDays + 1;
    final daysPassed = now.difference(challenge.startDate).inDays + 1;

    String status;
    Color statusColor;
    if (isCompleted) {
      status = 'Completed';
      statusColor = Colors.green.shade600;
    } else if (isActive) {
      status = 'Active';
      statusColor = AppColors.secondary;
    } else {
      status = 'Upcoming';
      statusColor = Colors.orange.shade600;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeSummaryPage(
              challenge: _convertChallengeToMap(challenge, progress, status),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    challenge.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date Range with month display
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(challenge.startDate)} - ${_formatDate(challenge.endDate)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Challenge Goals
            Row(
              children: [
                Icon(Icons.track_changes, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Goals: ${challenge.dailyCalorieGoal} cal • ${challenge.dailyWaterGoal} glasses daily',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isActive
                      ? 'Progress (Day $daysPassed of $daysTotal)'
                      : 'Progress ($daysPassed/$daysTotal days)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),

            // Notes (if any)
            if (challenge.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        challenge.notes,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatistic(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  int _calculateProgress(Challenge challenge) {
    final now = DateTime.now();
    final totalDays = challenge.endDate.difference(challenge.startDate).inDays + 1;
    final daysPassed = now.difference(challenge.startDate).inDays + 1;

    if (daysPassed <= 0) return 0;
    if (daysPassed >= totalDays) return 100;

    return ((daysPassed / totalDays) * 100).round();
  }

  Map<String, dynamic> _convertChallengeToMap(Challenge challenge, int progress, String status) {
    return {
      'title': challenge.title,
      'dateRange': '${_formatDate(challenge.startDate)} - ${_formatDate(challenge.endDate)}',
      'progress': progress,
      'status': status,
      'dailyCalorieGoal': challenge.dailyCalorieGoal,
      'dailyWaterGoal': challenge.dailyWaterGoal,
      'notes': challenge.notes,
      'startDate': challenge.startDate,
      'endDate': challenge.endDate,
    };
  }

  void _triggerCreateChallenge(BuildContext context) {
    // Show a simple message - you can integrate this with your create challenge flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navigate to create challenge'),
        action: SnackBarAction(
          label: 'Create',
          onPressed: () {
            // Here you would navigate to your challenge creation screen
            // or trigger the callback if provided
          },
        ),
      ),
    );
  }
}