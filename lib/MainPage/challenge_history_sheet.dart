import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:capstone_project/color/colors.dart';
import 'challenge_summary_page.dart';

class ChallengeHistorySheet extends StatelessWidget {
  const ChallengeHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Sample challenge data - replace with your actual data source
    final challenges = [
      {
        'title': '"The Thing" Challenge',
        'dateRange': 'Dec 1, 2025 - Dec 31, 2025',
        'progress': 100,
        'status': 'Completed'
      },
      {
        'title': '30 day Push up Challenge',
        'dateRange': 'Nov 1, 2025 - Nov 30, 2025',
        'progress': 100,
        'status': 'Completed'
      },
      {
        'title': '3min Plank per day challenge',
        'dateRange': 'Oct 1, 2025 - Oct 30, 2025',
        'progress': 100,
        'status': 'Completed'
      },
    ];

    // Check if challenges list is empty
    final bool isEmpty = challenges.isEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        // ✅ Compute stats here
        final totalChallenges = challenges.length;
        final completedChallenges =
            challenges.where((c) => c['status'] == 'Completed').length;
        final avgCompletion = completedChallenges > 0 ? 100 : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // --- Header Row ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Challenge History",
                    style: TextStyle(
                      fontSize: 18,
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

              // --- Scrollable List + Fixed Stats ---
              Expanded(
                child: Column(
                  children: [
                    // ✅ Scrollable list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          return _buildChallengeCard(challenges[index]);
                        },
                      ),
                    ),

                    // ✅ Fixed stats (won’t scroll)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatistic(totalChallenges.toString(),
                              "Total Challenges", AppColors.secondary),
                          _buildStatistic(completedChallenges.toString(), "Completed",
                              AppColors.secondary),
                          _buildStatistic(
                              "$avgCompletion%", "Avg. Completion", AppColors.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      },
    );

  }

  Widget _buildEmptyState(double screenWidth) {
    return Center(
      child: Column(
        children: [
          // Replace with your SVG icon
          Container(
            padding: const EdgeInsets.all(20), // space around the icon
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5), // light grey background
              shape: BoxShape.circle,   // makes it circular
            ),
            child: SvgPicture.asset(
              "assets/icons/nohistory.svg",
              width: screenWidth * 0.25,
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.srcIn,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            "No Challenge History",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "You haven't completed any challenges yet. Start your first challenge to begin tracking your fitness journey!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),


          SizedBox(
            width: screenWidth * 0.6,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF3F51B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Handle start challenge action
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Start A Challenge",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeList(List<Map<String, dynamic>> challenges) {
    final totalChallenges = challenges.length;
    final completedChallenges = challenges.where((c) => c['status'] == 'Completed').length;
    final avgCompletion = completedChallenges > 0 ? 100 : 0;

    return Column(
      children: [
        // Challenge Cards
        ...challenges.map((challenge) => _buildChallengeCard(challenge)).toList(),

        const SizedBox(height: 30),

        // Statistics Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatistic(totalChallenges.toString(), "Total Challenges", AppColors.secondary),
              _buildStatistic(completedChallenges.toString(), "Completed", AppColors.secondary),
              _buildStatistic("$avgCompletion%", "Avg. Completion", AppColors.secondary),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    return Builder(
      builder: (context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChallengeSummaryPage(challenge: challenge),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
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
                      challenge['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      challenge['status'],
                      style: TextStyle(
                        color: AppColors.secondary[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date Range
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    challenge['dateRange'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Progress",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "${challenge['progress']}%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Rounded Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: challenge['progress'] / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  minHeight: 8,
                ),
              ),
            ],
          ),
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
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}