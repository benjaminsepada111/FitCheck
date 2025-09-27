import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import '../MainPage/milestone_journey.dart';
import '../MainPage/trackers.dart';
import '../MainPage/challenge_calendar.dart';
import '../MainPage/custom_bottom_navbar.dart';
import '../MainPage/challenge_history_sheet.dart';
import '../MainPage/create_challenge_sheet.dart';

// add your other page imports
import 'food_page.dart';
import 'profile.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _selectedChallenge = "No Active Challenge";

  // Challenge and tracking data
  Challenge? _currentChallenge;
  int _currentCalories = 0;
  int _currentWater = 0;
  List<Challenge> _challengeHistory = [];

  // Keys for accessing child widget methods - remove this for now since we need to check the actual state class name
  // final GlobalKey<_TrackersState> _trackersKey = GlobalKey<_TrackersState>();

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
      builder: (context) => ChallengeHistorySheet(
        challengeHistory: _challengeHistory,
        onChallengeCreated: _onChallengeCreated,
      ),
    );
  }

  void _showCreateChallenge() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CreateChallengeSheet(
        onChallengeCreated: _onChallengeCreated,
      ),
    );
  }

  void _onChallengeCreated(Challenge challenge) {
    setState(() {
      _currentChallenge = challenge;
      _selectedChallenge = challenge.title;
      _challengeHistory.add(challenge);
    });

    // Refresh tracker data when new challenge is created
    _refreshTrackers();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Challenge "${challenge.title}" is now active across all tabs!',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),
      ),
    );
  }

  void _onChallengeEnded() {
    setState(() {
      _currentChallenge = null;
      _selectedChallenge = "No Active Challenge";
    });

    // Refresh tracker data when challenge ends
    _refreshTrackers();
  }

  void _onCaloriesChanged(int calories) {
    setState(() {
      _currentCalories = calories;
    });
    // The new system automatically saves to storage via FoodStorageService
    // No need to manually save here anymore
  }

  void _onWaterChanged(int water) {
    setState(() {
      _currentWater = water;
    });
    // The new system automatically saves to storage via WaterStorageService
    // No need to manually save here anymore
  }

  void _refreshTrackers() {
    // For now, we'll use a simpler approach without the key reference
    // The tracker will auto-refresh on challenge changes through setState
    setState(() {
      // This will trigger the widget to rebuild and fetch fresh data
    });
  }

  void _onChallengeSelected(String challengeTitle) {
    if (challengeTitle == "Create New Challenge") {
      _showCreateChallenge();
      return;
    }

    setState(() {
      _selectedChallenge = challengeTitle;
      if (challengeTitle == "No Active Challenge") {
        _currentChallenge = null;
      } else {
        // Find challenge in history
        try {
          _currentChallenge = _challengeHistory.firstWhere(
                  (challenge) => challenge.title == challengeTitle
          );
        } catch (e) {
          _currentChallenge = null;
        }
      }
    });

    // Refresh tracker data when challenge changes
    _refreshTrackers();
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems() {
    List<PopupMenuEntry<String>> items = [];

    // Current challenge or "No Active Challenge"
    items.add(
      PopupMenuItem(
        value: "No Active Challenge",
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _currentChallenge == null ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "No Active Challenge",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );

    // Add recent challenges from history
    for (Challenge challenge in _challengeHistory.take(3)) {
      items.add(
        PopupMenuItem(
          value: challenge.title,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: challenge.title == _selectedChallenge
                      ? Colors.green
                      : Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  challenge.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    items.add(const PopupMenuDivider());

    // Create new challenge option
    items.add(
      const PopupMenuItem(
        value: "Create New Challenge",
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
            SizedBox(width: 10),
            Text(
              "Create New Challenge",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );

    // View challenge history
    items.add(
      const PopupMenuItem(
        value: "View Challenge History",
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.black54, size: 20),
            SizedBox(width: 10),
            Text(
              "View Challenge History",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pass both currentChallenge and onCreateChallenge callback
              MilestoneJourney(
                currentChallenge: _currentChallenge,
                onCreateChallenge: _showCreateChallenge,
              ),
              const SizedBox(height: 20),
              // Updated Trackers widget - auto-refreshes when challenge changes
              Trackers(
                currentChallenge: _currentChallenge,
                onCaloriesChanged: _onCaloriesChanged,
                onWaterChanged: _onWaterChanged,
              ),
              const SizedBox(height: 20),
              ChallengeCalendar(
                currentChallenge: _currentChallenge,
                onChallengeCreated: _onChallengeCreated,
                onChallengeEnded: _onChallengeEnded,
              ),
            ],
          ),
        );
      case 1: // Food - Updated to pass challenge data and callback
        return FoodPage(
          currentChallenge: _currentChallenge,
          onChallengeCreated: _onChallengeCreated,
          // Remove this line since FoodPage doesn't have this parameter yet
          // onCaloriesUpdated: _refreshTrackers,
        );
      case 2: // Profile
        return const ProfilePage();
      default:
        return const Center(child: Text("Page not found"));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Profile page should not have the FitCheck header
    if (_selectedIndex == 2) {
      return Scaffold(
        body: _getBody(),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    }

    // Home & Food keep the header
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              pinned: true,
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
                    offset: const Offset(0, 20),
                    onSelected: (value) {
                      if (value == "View Challenge History") {
                        _showChallengeHistory();
                      } else {
                        _onChallengeSelected(value);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    elevation: 6,
                    itemBuilder: (context) => _buildPopupMenuItems(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentChallenge != null
                                  ? Colors.green
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              _selectedChallenge,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black54,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ];
        },
        body: _getBody(),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Wrapper to check user data and onboarding status
class MainPageWrapper extends StatelessWidget {
  const MainPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // For now, directly show MainPage
    // Later you can add logic to check if user has completed onboarding
    return const MainPage();
  }
}