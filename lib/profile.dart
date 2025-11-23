import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/Accounts/personal_info_page.dart';
import 'package:capstone_project/Accounts/change_password_page.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/models/user_data.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/achievements_page.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
import 'package:capstone_project/reminder_settings.dart';
import 'package:capstone_project/services/user_achievement_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  UserData? _userData;
  bool _isLoading = true;
  DateTime? _accountCreationDate;
  DateTime? _userStartDate;
  int _accountAgeDays = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> _unlockedAchievements = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadUserData();
    _loadAccountInfo();
    _loadUnlockedAchievements();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await UserDataService.loadUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAccountInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final creationDate = user.metadata.creationTime;
        final startDate = await UserTimeTracker.getUserStartDate();

        if (mounted && creationDate != null) {
          final now = DateTime.now();
          final ageInDays = now.difference(creationDate).inDays;

          setState(() {
            _accountCreationDate = creationDate;
            _userStartDate = startDate;
            _accountAgeDays = ageInDays;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadUnlockedAchievements() async {
    try {
      final achievements = await UserAchievementService.getAllAchievementsWithDetails();
      if (mounted) {
        setState(() {
          _unlockedAchievements = achievements
              .where((achievement) => achievement['unlocked'] == true)
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _logout(BuildContext context) async {
    final r = context.responsive;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.size(20)),
          ),
          backgroundColor: Colors.white,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                strokeWidth: r.size(3),
              ),
              ResponsiveGap(20, vertical: false),
              Text('Signing out...', style: TextStyle(fontSize: r.font(14, min: 12, max: 18))),
            ],
          ),
        ),
      );

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out. Please try again.',
                style: TextStyle(fontSize: r.font(14, min: 12, max: 18))),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(12)),
            ),
            margin: r.padding(all: 16),
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final r = context.responsive;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.size(24)),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Padding(
            padding: r.padding(all: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: r.padding(all: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade200,
                        blurRadius: r.size(12),
                        offset: Offset(0, r.size(4)),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: r.size(36),
                  ),
                ),
                ResponsiveGap(24),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: r.font(24, min: 20, max: 28),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                ResponsiveGap(12),
                Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.font(15, min: 13, max: 18),
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                ResponsiveGap(28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: r.paddingSymmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300, width: r.size(1.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.size(14)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: r.font(16, min: 14, max: 20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    ResponsiveGap(12, vertical: false),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _logout(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: r.paddingSymmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.size(14)),
                          ),
                        ),
                        child: Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.font(16, min: 14, max: 20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInitials() {
    if (_userData?.name != null && _userData!.name!.isNotEmpty) {
      final names = _userData!.name!.trim().split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return _userData!.name!.substring(0, 2).toUpperCase();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      return user!.email!.substring(0, 2).toUpperCase();
    }

    return 'U';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatAccountAge(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    if (days < 365) {
      final months = (days / 30).floor();
      return months == 1 ? '1 month' : '$months months';
    }
    final years = (days / 365).floor();
    return years == 1 ? '1 year' : '$years years';
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _getInitials(),
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Custom App Bar with Profile Header
            // Replace your entire SliverToBoxAdapter section (the profile header) with this:

            SliverToBoxAdapter(
              child: Container(
                child: Column(
                  children: [
                    // Top padding
                    SizedBox(height: 12),

                    // Profile Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
                          );
                          _loadUserData();
                        },
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.secondary,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Avatar with edit badge
                              Stack(
                                children: [
                                  Hero(
                                    tag: 'profile_avatar',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.secondary.withOpacity(0.3),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary.withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white,
                                        child: ClipOval(
                                          child: _userData?.profilePictureUrl?.isNotEmpty == true
                                              ? Image.network(
                                            _userData!.profilePictureUrl!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          )
                                              : _buildInitials(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary.withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16),

                              // Name
                              Text(
                                _userData?.name ?? user?.displayName ?? "User",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: 6),

                              // Email with icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      user?.email ?? "No email",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 10),

                              // Verified Badge (if verified)
                              if (FirebaseAuth.instance.currentUser?.emailVerified == true)
                                Container(
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),


            // Main Content
            SliverPadding(
              padding: r.padding(left: 16, right: 16, top: 8, bottom: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick Stats Card
                  _buildQuickStatsCard(r),
                  ResponsiveGap(16),

                  // Unlocked Achievements Section
                  if (_unlockedAchievements.isNotEmpty) ...[
                    _buildUnlockedAchievementsSection(r),
                    ResponsiveGap(16),
                  ],

                  // Achievements Card
                  _buildAchievementsCard(r),
                  ResponsiveGap(24),

                  // Account Section
                  _buildSectionHeader(r, 'Account'),
                  ResponsiveGap(12),
                  _buildSection(r, [
                    _buildListTile(
                      context,
                      r,
                      Icons.lock_outline_rounded,
                      "Change Password",
                      "Update your password",
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordPage(),
                        ),
                      ),
                    ),
                    _buildDivider(r),
                    _buildListTile(
                      context,
                      r,
                      Icons.shield_outlined,
                      "Two-Factor Authentication",
                      "Add extra security",
                      null,
                    ),
                    _buildDivider(r),
                    _buildListTile(
                      context,
                      r,
                      Icons.fingerprint_rounded,
                      "Biometric Login",
                      "Use fingerprint or face ID",
                      null,
                    ),
                  ]),
                  ResponsiveGap(24),

                  // Information Section
                  _buildSectionHeader(r, 'Information'),
                  ResponsiveGap(12),
                  _buildSection(r, [
                    _buildInfoTile(
                      r,
                      Icons.calendar_today_outlined,
                      "Joined",
                      _accountCreationDate != null
                          ? _formatDate(_accountCreationDate!)
                          : "Loading...",
                    ),
                    _buildDivider(r),
                    _buildInfoTile(
                      r,
                      Icons.access_time_outlined,
                      "Member for",
                      _accountAgeDays > 0
                          ? _formatAccountAge(_accountAgeDays)
                          : "Loading...",
                    ),
                    if (_userStartDate != null) ...[
                      _buildDivider(r),
                      _buildInfoTile(
                        r,
                        Icons.flag_outlined,
                        "Journey Started",
                        _formatDate(_userStartDate!),
                      ),
                    ],
                  ]),
                  ResponsiveGap(24),

                  // Preferences Section
                  _buildSectionHeader(r, 'Preferences'),
                  ResponsiveGap(12),
                  _buildSection(r, [
                    _buildSwitchTile(
                      context,
                      r,
                      Icons.dark_mode_outlined,
                      "Dark Mode",
                      "Switch to dark theme",
                      false,
                    ),
                    _buildDivider(r),
                    _buildListTile(
                      context,
                      r,
                      Icons.notifications_outlined,
                      "Notification Reminders",
                      "Manage meal & milestone reminders",
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReminderSettingsPage(),
                        ),
                      ),
                    ),
                  ]),
                  ResponsiveGap(24),

                  // Logout Button
                  _buildLogoutButton(context, r),
                  ResponsiveGap(24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedAchievementsSection(Responsive r) {
    return Container(
      padding: r.padding(all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.size(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: r.size(20),
            offset: Offset(0, r.size(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: r.padding(all: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(r.size(10)),
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.secondary,
                      size: r.size(20),
                    ),
                  ),
                  ResponsiveGap(12, vertical: false),
                  Text(
                    'Unlocked Achievements',
                    style: TextStyle(
                      fontSize: r.font(16, min: 14, max: 20),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: r.paddingSymmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(r.size(12)),
                ),
                child: Text(
                  '${_unlockedAchievements.length}',
                  style: TextStyle(
                    fontSize: r.font(14, min: 12, max: 16),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          ResponsiveGap(16),
          // Horizontal scrollable list of unlocked achievements
          SizedBox(
            height: r.size(120),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _unlockedAchievements.length,
              itemBuilder: (context, index) {
                final achievement = _unlockedAchievements[index];
                final imagePath = achievement['image'] as String?;
                final color = Color(achievement['color'] as int);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementsPage(),
                      ),
                    );
                  },
                  child: Container(
                    width: r.size(100),
                    margin: EdgeInsets.only(right: r.size(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Achievement Badge
                        Container(
                          width: r.size(70),
                          height: r.size(70),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: imagePath != null
                              ? Padding(
                            padding: EdgeInsets.all(r.size(8)),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.emoji_events_rounded,
                                  color: color,
                                  size: r.size(36),
                                );
                              },
                            ),
                          )
                              : Icon(
                            Icons.emoji_events_rounded,
                            color: color,
                            size: r.size(36),
                          ),
                        ),
                        ResponsiveGap(8),
                        // Achievement Title
                        Text(
                          achievement['title'] as String,
                          style: TextStyle(
                            fontSize: r.font(12, min: 10, max: 14),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ResponsiveGap(8),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(Responsive r) {
    return Container(
      padding: r.padding(all: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.size(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: r.size(20),
            offset: Offset(0, r.size(4)),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(r, Icons.event_available_rounded, "Days Active", "${_accountAgeDays}"),
          Container(
            width: r.size(1),
            height: r.size(40),
            color: Colors.grey.shade200,
            margin: r.paddingSymmetric(horizontal: 20),
          ),
          _buildStatItem(
            r,
            Icons.verified_user_rounded,
            "Verified",
            FirebaseAuth.instance.currentUser?.emailVerified == true ? "Yes" : "No",
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(Responsive r, IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: r.padding(all: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.size(14)),
            ),
            child: Icon(icon, color: AppColors.secondary, size: r.size(28)),
          ),
          ResponsiveGap(12),
          Text(
            value,
            style: TextStyle(
              fontSize: r.font(20, min: 18, max: 24),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          ResponsiveGap(4),
          Text(
            label,
            style: TextStyle(
              fontSize: r.font(13, min: 11, max: 16),
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard(Responsive r) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AchievementsPage()),
        );
      },
      child: Container(
        padding: r.padding(all: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade400,
              Colors.amber.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(r.size(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade300.withValues(alpha: 0.5),
              blurRadius: r.size(20),
              offset: Offset(0, r.size(8)),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: r.padding(all: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(r.size(16)),
              ),
              child: Image.asset(
                'assets/images/achievements/Star.png',
                width: r.size(48),
                height: r.size(48),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: r.size(48),
                  );
                },
              ),
            ),
            ResponsiveGap(16, vertical: false),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Achievements",
                    style: TextStyle(
                      fontSize: r.font(18, min: 16, max: 22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ResponsiveGap(4),
                  Text(
                    "View your progress & milestones",
                    style: TextStyle(
                      fontSize: r.font(14, min: 12, max: 18),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: r.padding(all: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(r.size(10)),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: r.size(18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(Responsive r, String title) {
    return Padding(
      padding: r.padding(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: r.font(13, min: 11, max: 16),
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
          textBaseline: TextBaseline.alphabetic,
        ).apply(heightFactor: 0.8),
      ),
    );
  }

  Widget _buildSection(Responsive r, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.size(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: r.size(20),
            offset: Offset(0, r.size(4)),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(Responsive r) {
    return Divider(
      height: r.size(1),
      thickness: r.size(1),
      color: Colors.grey.shade100,
      indent: r.size(72),
    );
  }

  Widget _buildListTile(
      BuildContext context,
      Responsive r,
      IconData icon,
      String title,
      String subtitle,
      VoidCallback? onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.size(20)),
        child: Padding(
          padding: r.paddingSymmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: r.padding(all: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.size(14)),
                ),
                child: Icon(icon, color: AppColors.secondary, size: r.size(24)),
              ),
              ResponsiveGap(16, vertical: false),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: r.font(16, min: 14, max: 20),
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    ResponsiveGap(4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: r.font(13, min: 11, max: 16),
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: r.size(24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
      BuildContext context,
      Responsive r,
      IconData icon,
      String title,
      String subtitle,
      bool value,
      ) {
    return Padding(
      padding: r.paddingSymmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: r.padding(all: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.size(14)),
            ),
            child: Icon(icon, color: AppColors.secondary, size: r.size(24)),
          ),
          ResponsiveGap(16, vertical: false),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.font(16, min: 14, max: 20),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                ResponsiveGap(4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: r.font(13, min: 11, max: 16),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) {},
            activeColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(Responsive r, IconData icon, String title, String value) {
    return Padding(
      padding: r.paddingSymmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: r.padding(all: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.size(14)),
            ),
            child: Icon(icon, color: AppColors.secondary, size: r.size(24)),
          ),
          ResponsiveGap(16, vertical: false),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: r.font(16, min: 14, max: 20),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: r.font(15, min: 13, max: 18),
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, Responsive r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.size(20)),
        border: Border.all(
          color: Colors.red.shade100,
          width: r.size(2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withValues(alpha: 0.3),
            blurRadius: r.size(20),
            offset: Offset(0, r.size(4)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(r.size(20)),
          child: Padding(
            padding: r.paddingSymmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: r.padding(all: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(r.size(14)),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: r.size(24),
                  ),
                ),
                ResponsiveGap(16, vertical: false),
                Expanded(
                  child: Text(
                    "Sign Out",
                    style: TextStyle(
                      fontSize: r.font(16, min: 14, max: 20),
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.red.shade400,
                  size: r.size(24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



Widget _buildStatCard({
  required IconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 15,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        SizedBox(height: 2),
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
    ),
  );
}