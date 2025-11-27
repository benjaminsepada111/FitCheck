import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/services/challenge_service.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
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
import 'services/weekly_checkin_service.dart';
import 'services/user_achievement_service.dart';
import 'UserInputFile/onboarding_wizard.dart';
import 'package:capstone_project/widgets/fitcheck_loader.dart';
import 'MainPage/weekly_checkin_wizard.dart';
import 'package:capstone_project/widgets/empty_state.dart';
import 'package:capstone_project/NotificationSettingsPage.dart';
import 'package:capstone_project/widgets/NotificationBellIcon.dart';
import 'services/challenge_completion_service.dart';
import 'widgets/challenge_completion_dialog.dart';


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

  Future<void> _checkChallengeCompletion() async {
    try {
      print('🔍 Checking challenge completion...');

      // Get all challenges to check for completed ones
      final allChallenges = await ChallengeService.getUserChallenges();

      // Find completed challenges that might need popup
      Challenge? completedChallenge;
      for (final challenge in allChallenges) {
        if (challenge.lifecycleStatus != 'cancelled' && challenge.isCompleted) {
          final justCompleted = ChallengeCompletionService.isChallengeJustCompleted(
            challenge.endDate,
          );

          if (justCompleted) {
            final hasShown = await ChallengeCompletionService.hasShownCompletionPopup(
              challenge.id,
            );

            if (!hasShown) {
              completedChallenge = challenge;
              break;
            }
          }
        }
      }

      if (completedChallenge == null) {
        print('❌ No completed challenge needs popup');
        return;
      }

      print('✅ Found completed challenge: ${completedChallenge.title}');
      print('🎉 Showing completion dialog AFTER empty state!');

      // Show completion dialog AFTER empty state is visible
      if (mounted) {
        // Wait a bit longer so user sees empty state first
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ChallengeCompletionDialog(
            challenge: completedChallenge!,
            onCreateNewChallenge: _showCreateChallenge,
            onDismiss: () {
              print('User dismissed completion dialog');
            },
          ),
        );

        print('Dialog closed, marking as shown');

        // Mark as shown
        await ChallengeCompletionService.markCompletionPopupShown(
          completedChallenge.id,
        );
      }
    } catch (e) {
      print('❌ Error in _checkChallengeCompletion: $e');
    }
  }

  /// Initialize with preloaded data, then continue background tasks
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

      // Check for challenge completion - will show popup AFTER empty state
      // Longer delay to ensure empty state renders first
      Future.delayed(const Duration(milliseconds: 1500), () {
        _checkChallengeCompletion();
      });

      // Check for weekly check-in (with delay for UI to settle)
      Future.delayed(const Duration(milliseconds: 2000), () {
        _checkWeeklyCheckIn();
      });

      // Refresh challenge data in background to ensure latest state
      _refreshChallengeDataInBackground();
    } catch (e) {
      print('Error initializing: $e');
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
          final r = context.responsive;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: r.size(24),
                  ),
                  ResponsiveGap.horizontal(12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Achievement Unlocked!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: r.font(14, min: 12, max: 16),
                          ),
                        ),
                        Text(
                          achievement['title'] as String,
                          style: TextStyle(
                            fontSize: r.font(13, min: 11, max: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.size(12)),
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
        final needsCheckIn = await WeeklyCheckInService.needsCheckIn(
          _currentChallenge!,
        );
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
  /// Refresh challenge data in the background without blocking UI
  Future<void> _refreshChallengeDataInBackground() async {
    try {
      // Get all challenges first
      final allChallenges = await ChallengeService.getUserChallenges();
      // Get only active (non-cancelled, non-completed) challenges
      final activeChallenges = allChallenges.where((c) =>
      c.lifecycleStatus == 'active' &&
          c.isActive &&
          !c.isCompleted
      ).toList();

      if (mounted) {
        setState(() {
          _challengeHistory = allChallenges;

          // Set current challenge only if there's a truly active one
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
      print('Error refreshing challenge data: $e');
      // Silently handle background refresh errors
    }
  }

  Future<void> _loadChallengeData() async {
    try {
      // Get all challenges first
      final allChallenges = await ChallengeService.getUserChallenges();
      // Get only active (non-cancelled, non-completed) challenges
      final activeChallenges = allChallenges.where((c) =>
      c.lifecycleStatus == 'active' &&
          c.isActive &&
          !c.isCompleted
      ).toList();

      if (mounted) {
        setState(() {
          _challengeHistory = allChallenges;

          // Set current challenge only if there's a truly active one
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
      print('Error loading challenge data: $e');
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
    final r = context.responsive;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.size(20))),
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

    final r = context.responsive;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: r.size(20)),
            ResponsiveGap.horizontal(8),
            Expanded(
              child: Text(
                'Challenge "${challenge.title}" is now active across all tabs!',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: r.font(14, min: 12, max: 16),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.size(10)),
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
    final r = context.responsive;
    List<PopupMenuEntry<String>> items = [];

    // If there's a current active challenge, only show that one
    if (_currentChallenge != null && _currentChallenge!.lifecycleStatus != 'cancelled') {
      items.add(
        PopupMenuItem(
          value: _currentChallenge!.title,
          child: Row(
            children: [
              Container(
                width: r.size(10),
                height: r.size(10),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              ResponsiveGap.horizontal(10),
              Expanded(
                child: Text(
                  _currentChallenge!.title,
                  style: TextStyle(
                    fontSize: r.font(14, min: 12, max: 16),
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
    } else {
      // No active challenge or current challenge is cancelled
      items.add(
        PopupMenuItem(
          value: "No Active Challenge",
          child: Row(
            children: [
              Container(
                width: r.size(10),
                height: r.size(10),
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              ResponsiveGap.horizontal(10),
              Text(
                "No Active Challenge",
                style: TextStyle(
                  fontSize: r.font(14, min: 12, max: 16),
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
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
        PopupMenuItem(
          value: "Create New Challenge",
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: AppColors.secondary,
                size: r.size(20),
              ),
              ResponsiveGap.horizontal(10),
              Text(
                "Create New Challenge",
                style: TextStyle(
                  fontSize: r.font(14, min: 12, max: 16),
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
        PopupMenuItem(
          value: "Cancel Challenge",
          child: Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: Colors.orange,
                size: r.size(20),
              ),
              ResponsiveGap.horizontal(10),
              Text(
                "Cancel Challenge",
                style: TextStyle(
                  fontSize: r.font(14, min: 12, max: 16),
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
      PopupMenuItem(
        value: "View Challenge History",
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.black54, size: r.size(20)),
            ResponsiveGap.horizontal(10),
            Text(
              "View Challenge History",
              style: TextStyle(
                fontSize: r.font(14, min: 12, max: 16),
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
    final r = context.responsive;
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // HOME PAGE
        _currentChallenge == null
            ? EmptyState(
          type: EmptyStateType.noChallengeHome,
          onAction: _showCreateChallenge,
        )
            : SingleChildScrollView(
          padding: r.paddingSymmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MilestoneJourney(
                key: _milestoneKey,
                currentChallenge: _currentChallenge,
                onCreateChallenge: _showCreateChallenge,
              ),
              ResponsiveGap.vertical(12),
              Trackers(
                key: _trackersKey,
                currentChallenge: _currentChallenge,
                onCaloriesChanged: _onCaloriesChanged,
              ),
              ResponsiveGap.vertical(12),
              ChallengeCalendar(
                currentChallenge: _currentChallenge,
                onChallengeCreated: _onChallengeCreated,
                onChallengeEnded: _onChallengeEnded,
              ),
            ],
          ),
        ),

        // FOOD PAGE
        _currentChallenge == null
            ? EmptyState(
          type: EmptyStateType.noChallengeFood,
          onAction: _showCreateChallenge,
        )
            : FoodPage(
          key: _foodPageKey,
          currentChallenge: _currentChallenge,
          onChallengeCreated: _onChallengeCreated,
          onCaloriesUpdated: _refreshTrackers,
        ),

        // WORKOUT PAGE
        _currentChallenge == null
            ? EmptyState(
          type: EmptyStateType.noChallengeWorkout,
          onAction: _showCreateChallenge,
        )
            : WorkoutHistoryPage(
          key: _workoutPageKey,
          currentChallenge: _currentChallenge,
        ),

        // PROFILE PAGE
        const ProfilePage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

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
              elevation: r.size(4),
              shadowColor: Colors.black.withValues(alpha: 0.1),
              toolbarHeight: r.size(56),
              title: Row(
                children: [
                  // FitCheck Title - Splash Screen Style
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: r.font(38, min: 26, max: 45),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Fit',
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: 'Check',
                          style: TextStyle(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ResponsiveGap.horizontal(10),
                  // Notification Icon
                  NotificationIconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      );
                    },
                    iconColor: Colors.black87,
                    badgeColor: Colors.red,
                  ),

                  ResponsiveGap.horizontal(6),

                  // Challenge Selector Dropdown - Wrapped in Expanded
                  Expanded(
                    child: PopupMenuButton<String>(
                      offset: Offset(r.size(20), r.size(30)),
                      onSelected: (value) {
                        if (value == "View Challenge History") {
                          _showChallengeHistory();
                        } else {
                          _onChallengeSelected(value);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.size(12)),
                      ),
                      color: Colors.white,
                      elevation: r.size(6),
                      itemBuilder: (context) => _buildPopupMenuItems(),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.4,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: r.size(10),
                          vertical: r.size(6),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(r.size(10)),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: r.size(10),
                              height: r.size(10),
                              decoration: BoxDecoration(
                                color: _currentChallenge != null ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            ResponsiveGap.horizontal(8),

                            /// MAKE TEXT TAKE ALL AVAILABLE SPACE
                            Expanded(
                              child: Text(
                                _selectedChallenge,
                                style: TextStyle(
                                  fontSize: r.font(14, min: 12, max: 16),
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),

                            /// ICON ALWAYS STAYS RIGHT SIDE
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black54,
                              size: r.size(18),
                            ),
                          ],
                        )
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
  Future<void> _preloadChallengeData() async {
    try {
      // Get all challenges first
      final allChallenges = await ChallengeService.getUserChallenges();

      if (mounted) {
        setState(() {
          _preloadedChallengeHistory = allChallenges;

          // Just find active challenges
          final activeChallenges = allChallenges.where((c) =>
          c.lifecycleStatus == 'active' &&
              c.isActive &&
              !c.isCompleted
          ).toList();

          _preloadedChallenge = activeChallenges.isNotEmpty ? activeChallenges.first : null;
        });
      }
    } catch (e) {
      print('Error preloading challenge data: $e');
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
      // User needs to complete profile setup - start with onboarding wizard
      return const OnboardingWizard();
    }
  }
}