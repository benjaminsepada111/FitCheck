import 'package:flutter/material.dart';
import '../widgets/milestone_journey.dart';
import '../widgets/trackers.dart';
import '../widgets/challenge_calendar.dart';
import '../widgets/custom_bottom_navbar.dart';
import '../widgets/challenge_history_sheet.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _selectedChallenge = "Challenge Title";

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showChallengeHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChallengeHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              pinned: true, // keeps it visible
              elevation: 0,
              toolbarHeight: 70,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "FitCheck",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "View Challenge History") {
                        _showChallengeHistory();
                      } else {
                        setState(() {
                          _selectedChallenge = value;
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "No Active Challenge",
                        child: Text("No Active Challenge"),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: "View Challenge History",
                        child: Text("View Challenge History"),
                      ),
                    ],
                    child: Row(
                      children: [
                        Text(
                          _selectedChallenge,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 20),
              MilestoneJourney(),
              SizedBox(height: 20),
              Trackers(),
              SizedBox(height: 20),
              ChallengeCalendar(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
