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
import 'package:capstone_project/widgets/fitcheck_loader.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserData? _userData;
  bool _isLoading = true;
  DateTime? _accountCreationDate;
  DateTime? _userStartDate;
  int _accountAgeDays = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAccountInfo();
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
        // Get account creation date from Firebase Auth
        final creationDate = user.metadata.creationTime;

        // Get user start date from time tracking
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

  Future<void> _logout(BuildContext context) async {
    final r = context.responsive;
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.size(16)),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
              ResponsiveGap(20, vertical: false),
              Text('Signing out...', style: TextStyle(fontSize: r.font(14, min: 12, max: 18))),
            ],
          ),
        ),
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Show logout notification
      await NotificationService().showLogoutNotification();

      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Navigate to auth page
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out. Please try again.',
                style: TextStyle(fontSize: r.font(14, min: 12, max: 18))),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.size(10)),
            ),
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
            borderRadius: BorderRadius.circular(r.size(20)),
          ),
          child: Padding(
            padding: r.padding(all: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: r.padding(all: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade600,
                    size: r.size(32),
                  ),
                ),
                ResponsiveGap(20),
                Text(
                  'Sign Out',
                  style: TextStyle(fontSize: r.font(22, min: 18, max: 26), fontWeight: FontWeight.bold),
                ),
                ResponsiveGap(12),
                Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.font(15, min: 13, max: 18),
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                ResponsiveGap(24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: r.paddingSymmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.size(12)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                          padding: r.paddingSymmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.size(12)),
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
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatAccountAge(int days) {
    if (days == 0) {
      return 'Today';
    } else if (days == 1) {
      return '1 day';
    } else if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      final months = (days / 30).floor();
      final remainingDays = days % 30;
      if (months == 1) {
        return remainingDays > 0 ? '1 month, $remainingDays days' : '1 month';
      }
      return remainingDays > 0
          ? '$months months, $remainingDays days'
          : '$months months';
    } else {
      final years = (days / 365).floor();
      final months = ((days % 365) / 30).floor();
      if (years == 1) {
        return months > 0 ? '1 year, $months months' : '1 year';
      }
      return months > 0 ? '$years years, $months months' : '$years years';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: FitCheckLoader())
          : ListView(
        padding: r.padding(all: 16),
        children: [
          // Enhanced Profile Card - Now Clickable
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalInfoPage(),
                ),
              );
              // Reload user data after returning from PersonalInfoPage
              _loadUserData();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.secondary,
                    AppColors.secondary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(r.size(16)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: r.size(12),
                    offset: Offset(0, r.size(4)),
                  ),
                ],
              ),
              child: Padding(
                padding: r.padding(all: 20),
                child: Row(
                  children: [
                    Container(
                      padding: r.padding(all: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: r.size(2),
                        ),
                      ),
                      child: _userData?.profilePictureUrl != null &&
                          _userData!.profilePictureUrl!.isNotEmpty
                          ? CircleAvatar(
                        radius: r.size(30),
                        backgroundColor: Colors.white.withValues(
                          alpha: 0.2,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _userData!.profilePictureUrl!,
                            fit: BoxFit.cover,
                            width: r.size(60),
                            height: r.size(60),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: r.size(2),
                                  valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                _getInitials(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.font(20, min: 16, max: 24),
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                          : CircleAvatar(
                        radius: r.size(30),
                        backgroundColor: Colors.white.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          _getInitials(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.font(20, min: 16, max: 24),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    ResponsiveGap(16, vertical: false),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?.name ??
                                user?.displayName ??
                                'User',
                            style: TextStyle(
                              fontSize: r.font(18, min: 16, max: 22),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          ResponsiveGap(6),
                          Text(
                            user?.email ?? "No email",
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(r.size(10)),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: r.size(20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          ResponsiveGap(16),

          // Achievements Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AchievementsPage()),
              );
            },
            child: Container(
              padding: r.paddingSymmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.amber.shade100.withValues(alpha: 0.15),
                    Colors.amber.shade100.withValues(alpha: 0.25),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                borderRadius: BorderRadius.circular(r.size(16)),
                border: Border.all(color: Colors.grey.shade200, width: r.size(1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: r.size(12),
                    offset: Offset(0, r.size(3)),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Badge icon with Star image
                  Image.asset(
                    'assets/images/achievements/Star.png',
                    width: r.size(70),
                    height: r.size(70),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails
                      return Container(
                        width: r.size(70),
                        height: r.size(70),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.amber.shade400, Colors.amber.shade600],
                          ),
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: r.size(38),
                        ),
                      );
                    },
                  ),
                  ResponsiveGap(12, vertical: false),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Achievements",
                          style: TextStyle(
                            fontSize: r.font(15, min: 13, max: 18),
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        ResponsiveGap(3),
                        Text(
                          "View your progress and milestones",
                          style: TextStyle(
                              fontSize: r.font(13, min: 11, max: 16),
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(Icons.chevron_right,
                      color: Colors.amber.shade700, size: r.size(26)),
                ],
              ),
            ),
          ),

          ResponsiveGap(24),

          // Section Header
          Padding(
            padding: r.padding(left: 4, bottom: 12),
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: r.font(16, min: 14, max: 20),
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // Account Settings
          _buildSection(r, [
            _buildListTile(
              context,
              r,
              Icons.vpn_key_outlined,
              "Change Password",
              "Update your password",
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage(),
                ),
              ),
            ),
            Divider(height: r.size(1), indent: r.size(60)),
            _buildListTile(
              context,
              r,
              Icons.shield_outlined,
              "Two Factor Authentication",
              "Add extra security",
              null,
            ),
            Divider(height: r.size(1), indent: r.size(60)),
            _buildListTile(
              context,
              r,
              Icons.fingerprint,
              "Biometric Login",
              "Use fingerprint or face ID",
              null,
            ),
          ]),

          ResponsiveGap(24),

          // Account Information Section
          Padding(
            padding: r.padding(left: 4, bottom: 12),
            child: Text(
              'Account Information',
              style: TextStyle(
                fontSize: r.font(16, min: 14, max: 20),
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          _buildSection(r, [
            _buildInfoTile(
              r,
              Icons.calendar_today_outlined,
              "Account Created",
              _accountCreationDate != null
                  ? _formatDate(_accountCreationDate!)
                  : "Loading...",
            ),
            Divider(height: r.size(1), indent: r.size(60)),
            _buildInfoTile(
              r,
              Icons.access_time_outlined,
              "Account Age",
              _accountAgeDays > 0
                  ? _formatAccountAge(_accountAgeDays)
                  : "Loading...",
            ),
            if (_userStartDate != null) ...[
              Divider(height: r.size(1), indent: r.size(60)),
              _buildInfoTile(
                r,
                Icons.flag_outlined,
                "Journey Started",
                _formatDate(_userStartDate!),
              ),
            ],
            Divider(height: r.size(1), indent: r.size(60)),
            _buildInfoTile(
              r,
              Icons.verified_user_outlined,
              "Email Verified",
              FirebaseAuth.instance.currentUser?.emailVerified == true
                  ? "Yes"
                  : "No",
            ),
          ]),

          ResponsiveGap(24),

          // Section Header
          Padding(
            padding: r.padding(left: 4, bottom: 12),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontSize: r.font(16, min: 14, max: 20),
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // Preferences
          _buildSection(r, [
            _buildSwitchTile(
              context,
              r,
              Icons.dark_mode_outlined,
              "Dark Mode",
              "Switch to dark theme",
              false,
            ),
            Divider(height: r.size(1), indent: r.size(60)),
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.size(16)),
              border: Border.all(color: Colors.red.shade200, width: r.size(1.5)),
            ),
            child: ListTile(
              onTap: () => _showLogoutDialog(context),
              contentPadding: r.paddingSymmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: r.padding(all: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(r.size(12)),
                ),
                child: Icon(
                  Icons.logout,
                  color: Colors.red.shade600,
                  size: r.size(22),
                ),
              ),
              title: Text(
                "Log Out",
                style: TextStyle(
                  fontSize: r.font(16, min: 14, max: 20),
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Colors.red.shade400,
                size: r.size(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildListTile(
      BuildContext context,
      Responsive r,
      IconData icon,
      String title,
      String subtitle,
      VoidCallback? onTap,
      ) {
    return ListTile(
      onTap: onTap,
      contentPadding: r.paddingSymmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: r.padding(all: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.size(12)),
        ),
        child: Icon(icon, color: AppColors.secondary, size: r.size(22)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: r.font(15, min: 13, max: 18),
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: r.font(13, min: 11, max: 16), color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey.shade400,
        size: r.size(16),
      ),
    );
  }

  static Widget _buildSwitchTile(
      BuildContext context,
      Responsive r,
      IconData icon,
      String title,
      String subtitle,
      bool value,
      ) {
    return SwitchListTile(
      value: value,
      onChanged: (_) {},
      contentPadding: r.paddingSymmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: r.font(15, min: 13, max: 18),
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: r.font(13, min: 11, max: 16), color: Colors.grey.shade600),
      ),
      secondary: Container(
        padding: r.padding(all: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.size(12)),
        ),
        child: Icon(icon, color: AppColors.secondary, size: r.size(22)),
      ),
      activeColor: AppColors.secondary,
      activeTrackColor: AppColors.secondary.withValues(alpha: 0.3),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  static Widget _buildInfoTile(Responsive r, IconData icon, String title, String value) {
    return ListTile(
      contentPadding: r.paddingSymmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: r.padding(all: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.size(12)),
        ),
        child: Icon(icon, color: AppColors.secondary, size: r.size(22)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: r.font(15, min: 13, max: 18),
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: r.font(14, min: 12, max: 18),
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  static Widget _buildSection(Responsive r, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.size(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: r.size(10),
            offset: Offset(0, r.size(2)),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}