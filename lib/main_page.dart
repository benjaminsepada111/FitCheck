import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/challenge_service.dart';
import 'app_text_styles.dart';
import '../MainPage/milestone_journey.dart';
import '../MainPage/trackers.dart';
import '../MainPage/challenge_calendar.dart';
import '../MainPage/custom_bottom_navbar.dart';
import '../MainPage/challenge_history_sheet.dart';
import '../MainPage/create_challenge_sheet.dart';
import 'package:capstone_project/color/colors.dart';
import 'food_page.dart';
import 'profile.dart';
import 'WorkoutPage/workout_history_page.dart';
import 'services/user_data_service.dart';
import 'services/user_time_tracker.dart';
import 'services/login_tracker_service.dart';
import 'services/user_achievement_service.dart';
import 'services/weekly_checkin_service.dart';
import 'UserInputFile/genderselection.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'MainPage/weekly_checkin_wizard.dart';

class MainPage extends StatefulWidget {
  final Challenge? initialChallenge;
  final List<Challenge>? initialChallengeHistory;

  const MainPage({
    super.key,
    this.initialChallenge,
    this.initialChallengeHistory,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _selectedChallenge = "No Challenge";

  Challenge? _currentChallenge;
  List<Challenge> _challengeHistory = [];

  // GlobalKeys to maintain widget identity across rebuilds
  final GlobalKey _milestoneKey = GlobalKey();
  final GlobalKey _foodPageKey = GlobalKey();
  final GlobalKey _workoutPageKey = GlobalKey();
  final GlobalKey<TrackersState> _trackersKey = GlobalKey<TrackersState>();

  @override
  void initState() {
    super.initState();
    _initializeWithPreloadedData();
  }

  /// Initialize with preloaded data, then continue background tasks
  Future<void> _initializeWithPreloadedData() async {
    try {
      // Use preloaded data if provided
      if (widget.initialChallenge != null ||
          widget.initialChallengeHistory != null) {
        if (mounted) {
          setState(() {
            _currentChallenge = widget.initialChallenge;
            _challengeHistory = widget.initialChallengeHistory ?? [];
            _selectedChallenge =
                widget.initialChallenge?.title ?? "No Challenge";
          });
        }
      } else {
        // Fallback: load data synchronously if no preload
        await _loadChallengeData();
      }

      // Start background tasks (don't wait for these)
      _initializeTimeTracking();
      _recordDailyLogin();

      // Check for weekly check-in (with delay for UI to settle)
      Future.delayed(const Duration(milliseconds: 800), () {
        _checkWeeklyCheckIn();
      });

      // Refresh challenge data in background to ensure latest state
      _refreshChallengeDataInBackground();
    } catch (e) {
      // Error handled, no action needed
    }
  }

  /// Initialize time tracking for the user on app startup
  Future<void> _initializeTimeTracking() async {
    try {
      final isInitialized = await UserTimeTracker.isInitialized();
      if (!isInitialized) {
        await UserTimeTracker.initializeUserStartDate();
      }
    } catch (e) {
      // Silently handle time tracking initialization errors
    }
  }

  /// Record that user opened the app today
  Future<void> _recordDailyLogin() async {
    try {
      await LoginTrackerService.recordDailyLogin();
      await UserAchievementService.trackDailyLogin();

      final newlyUnlocked =
          await UserAchievementService.checkAndUnlockAchievements();

      if (newlyUnlocked.isNotEmpty && mounted) {
        for (final id in newlyUnlocked) {
          final achievement = UserAchievementService.getAchievementWithMetadata(
            id,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Achievement Unlocked!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          achievement['title'] as String,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle daily login errors
    }
  }

  /// Check if user needs a weekly check-in and show wizard
  Future<void> _checkWeeklyCheckIn() async {
    try {
      if (_currentChallenge != null) {
        final needsCheckIn = await WeeklyCheckInService.needsCheckIn(_currentChallenge!);
        if (needsCheckIn && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeeklyCheckInWizard(
                challenge: _currentChallenge!,
                onCheckInComplete: () {
                  // Refresh trackers and challenge data after check-in
                  _trackersKey.currentState?.refreshData();
                  _refreshChallengeDataInBackground();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle check-in wizard errors
    }
  }

  /// Refresh challenge data in the background without blocking UI
  Future<void> _refreshChallengeDataInBackground() async {
    try {
      final allChallenges = await ChallengeService.getUserChallenges();
      final activeChallenges = await ChallengeService.getActiveChallenges();

      if (mounted) {
        setState(() {
          _challengeHistory = allChallenges;

          if (activeChallenges.isNotEmpty) {
            _currentChallenge = activeChallenges.first;
            _selectedChallenge = _currentChallenge!.title;
          } else {
            _currentChallenge = null;
            _selectedChallenge = "No Challenge";
          }
        });
      }
    } catch (e) {
      // Silently handle background refresh errors
    }
  }

  Future<void> _loadChallengeData() async {
    try {
      final allChallenges = await ChallengeService.getUserChallenges();
      final activeChallenges = await ChallengeService.getActiveChallenges();

      if (mounted) {
        setState(() {
          _challengeHistory = allChallenges;

          if (activeChallenges.isNotEmpty) {
            _currentChallenge = activeChallenges.first;
            _selectedChallenge = _currentChallenge!.title;
          } else {
            _currentChallenge = null;
            _selectedChallenge = "No Active Challenge";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _challengeHistory = [];
          _currentChallenge = null;
          _selectedChallenge = "No Active Challenge";
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Removed _milestoneKey++ - it was forcing unnecessary rebuilds
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
      builder: (context) =>
          CreateChallengeSheet(onChallengeCreated: _onChallengeCreated),
    );
  }

  void _showCancelChallengeDialog() {
    if (_currentChallenge == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Challenge'),
          content: Text(
            'Are you sure you want to cancel "${_currentChallenge!.title}"?\n\nYou can still view it in Challenge History, and delete it permanently from there if needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Active'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelCurrentChallenge();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Cancel Challenge'),
            ),
          ],
        );
      },
    );
  }

  void _cancelCurrentChallenge() async {
    if (_currentChallenge == null) return;

    try {
      final success = await ChallengeService.cancelChallenge(
        _currentChallenge!.id,
      );

      if (success) {
        await _loadChallengeData();
      } else {
        throw Exception('Failed to cancel challenge');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Challenge cancelled. View it in Challenge History.',
          ),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'View History',
            textColor: Colors.white,
            onPressed: () {
              _showChallengeHistory();
            },
          ),
        ),
      );

      _refreshTrackers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel challenge'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onChallengeCreated(Challenge challenge) {
    setState(() {
      _currentChallenge = challenge;
      _selectedChallenge = challenge.title;
      _challengeHistory.add(challenge);
    });

    _loadChallengeData();
    _refreshTrackers();

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    _refreshTrackers();
  }

  void _onCaloriesChanged(int calories) {
    // Callback for when calories change in Trackers widget
    // Currently just used for notification, no state update needed
  }

  void _refreshTrackers() {
    // Refresh the Trackers widget to reload calorie data
    _trackersKey.currentState?.refreshData();
  }

  void _onChallengeSelected(String challengeTitle) {
    if (challengeTitle == "Create New Challenge") {
      _showCreateChallenge();
      return;
    }

    if (challengeTitle == "Cancel Challenge") {
      _showCancelChallengeDialog();
      return;
    }

    setState(() {
      _selectedChallenge = challengeTitle;
      if (challengeTitle == "No Active Challenge") {
        _currentChallenge = null;
      } else {
        try {
          _currentChallenge = _challengeHistory.firstWhere(
            (challenge) => challenge.title == challengeTitle,
          );
        } catch (e) {
          _currentChallenge = null;
        }
      }
    });

    _refreshTrackers();
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems() {
    List<PopupMenuEntry<String>> items = [];

    if (_currentChallenge == null) {
      items.add(
        PopupMenuItem(
          value: "No Active Challenge",
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.grey,
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
    }

    for (Challenge challenge in _challengeHistory.take(3)) {
      if (_currentChallenge != null && challenge.id != _currentChallenge!.id) {
        continue;
      }

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

    if (_currentChallenge == null) {
      items.add(
        const PopupMenuItem(
          value: "Create New Challenge",
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: AppColors.secondary,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                "Create New Challenge",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      items.add(
        const PopupMenuItem(
          value: "Cancel Challenge",
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 10),
              Text(
                "Cancel Challenge",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
    // Use IndexedStack to keep pages alive and prevent rebuilding
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Home page (index 0)
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MilestoneJourney(
                key:
                    _milestoneKey, // GlobalKey maintains identity across rebuilds
                currentChallenge: _currentChallenge,
                onCreateChallenge: _showCreateChallenge,
              ),
              const SizedBox(height: 12),
              Trackers(
                key: _trackersKey,
                currentChallenge: _currentChallenge,
                onCaloriesChanged: _onCaloriesChanged,
              ),
              const SizedBox(height: 12),
              ChallengeCalendar(
                currentChallenge: _currentChallenge,
                onChallengeCreated: _onChallengeCreated,
                onChallengeEnded: _onChallengeEnded,
              ),
            ],
          ),
        ),
        // Food page (index 1)
        FoodPage(
          key: _foodPageKey, // GlobalKey maintains identity across rebuilds
          currentChallenge: _currentChallenge,
          onChallengeCreated: _onChallengeCreated,
          onCaloriesUpdated: _refreshTrackers,
        ),
        // Workout page (index 2)
        WorkoutHistoryPage(
          key: _workoutPageKey, // GlobalKey maintains identity across rebuilds
          currentChallenge: _currentChallenge,
        ),
        // Profile page (index 3)
        const ProfilePage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              pinned: true,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              toolbarHeight: 60,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("FitCheck", style: AppTextStyles.appTitle),
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
                  ),
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
class MainPageWrapper extends StatefulWidget {
  const MainPageWrapper({super.key});

  @override
  State<MainPageWrapper> createState() => _MainPageWrapperState();
}

class _MainPageWrapperState extends State<MainPageWrapper> {
  bool _isLoading = true;
  bool _isProfileComplete = false;
  Challenge? _preloadedChallenge;
  List<Challenge> _preloadedChallengeHistory = [];

  @override
  void initState() {
    super.initState();
    _preloadDataAndCheckProfile();
  }

  /// Preload all data while showing loader, then check profile
  Future<void> _preloadDataAndCheckProfile() async {
    try {
      // Run profile check and data preloading in parallel
      final results = await Future.wait([
        _checkUserProfileAsync(),
        _preloadChallengeData(),
      ]);

      final profileComplete = results[0] as bool;

      if (mounted) {
        setState(() {
          _isProfileComplete = profileComplete;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProfileComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Check user profile asynchronously
  Future<bool> _checkUserProfileAsync() async {
    try {
      final hasData = await UserDataService.hasUserData();
      final profileComplete = await UserDataService.isProfileComplete();
      return hasData && profileComplete;
    } catch (e) {
      return false;
    }
  }

  /// Preload challenge data in background
  Future<void> _preloadChallengeData() async {
    try {
      final allChallenges = await ChallengeService.getUserChallenges();
      final activeChallenges = await ChallengeService.getActiveChallenges();

      if (mounted) {
        setState(() {
          _preloadedChallengeHistory = allChallenges;
          _preloadedChallenge = activeChallenges.isNotEmpty
              ? activeChallenges.first
              : null;
        });
      }
    } catch (e) {
      // Continue anyway - MainPage will load data if preload fails
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: FitCheckLoader(fullscreen: true),
      );
    }

    if (_isProfileComplete) {
      // User has completed profile setup - show main app with preloaded data
      return MainPage(
        initialChallenge: _preloadedChallenge,
        initialChallengeHistory: _preloadedChallengeHistory,
      );
    } else {
      // User needs to complete profile setup
      return const GenderSelection();
    }
  }
}
