import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/Accounts/personal_info_page.dart';
import 'package:capstone_project/Accounts/change_password_page.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/services/user_data_service.dart';
import 'package:capstone_project/services/user_time_tracker.dart';
import 'package:capstone_project/models/user_data.dart';

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
      debugPrint('Error loading user data: $e');
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
    } catch (e) {
      debugPrint('Error loading account info: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
              const SizedBox(width: 20),
              const Text('Signing out...'),
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
            content: const Text('Failed to sign out. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _logout(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
      return remainingDays > 0 ? '$months months, $remainingDays days' : '$months months';
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Account",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Enhanced Profile Card - Now Clickable
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
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
                          AppColors.secondary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Text(
                                _getInitials(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userData?.name ?? user?.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user?.email ?? "No email",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Section Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                // Account Settings (Personal Info removed)
                _buildSection([
                  _buildListTile(
                    context,
                    Icons.vpn_key_outlined,
                    "Change Password",
                    "Update your password",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    context,
                    Icons.shield_outlined,
                    "Two Factor Authentication",
                    "Add extra security",
                    null,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    context,
                    Icons.fingerprint,
                    "Biometric Login",
                    "Use fingerprint or face ID",
                    null,
                  ),
                ]),

                const SizedBox(height: 24),

                // Account Information Section
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                _buildSection([
                  _buildInfoTile(
                    Icons.calendar_today_outlined,
                    "Account Created",
                    _accountCreationDate != null
                        ? _formatDate(_accountCreationDate!)
                        : "Loading...",
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildInfoTile(
                    Icons.access_time_outlined,
                    "Account Age",
                    _accountAgeDays > 0
                        ? _formatAccountAge(_accountAgeDays)
                        : "Loading...",
                  ),
                  if (_userStartDate != null) ...[
                    const Divider(height: 1, indent: 60),
                    _buildInfoTile(
                      Icons.flag_outlined,
                      "Journey Started",
                      _formatDate(_userStartDate!),
                    ),
                  ],
                  const Divider(height: 1, indent: 60),
                  _buildInfoTile(
                    Icons.verified_user_outlined,
                    "Email Verified",
                    FirebaseAuth.instance.currentUser?.emailVerified == true
                        ? "Yes"
                        : "No",
                  ),
                ]),

                const SizedBox(height: 24),

                // Section Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                // Preferences
                _buildSection([
                  _buildSwitchTile(
                    context,
                    Icons.dark_mode_outlined,
                    "Dark Mode",
                    "Switch to dark theme",
                    false,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    context,
                    Icons.notifications_outlined,
                    "Notifications",
                    "Manage notification settings",
                    null,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    context,
                    Icons.language_outlined,
                    "Language",
                    "Choose your preferred language",
                    null,
                  ),
                ]),

                const SizedBox(height: 24),

                // Section Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'More',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                // More Options
                _buildSection([
                  _buildListTile(
                    context,
                    Icons.help_outline,
                    "Help & Support",
                    "Get help with the app",
                    null,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    context,
                    Icons.info_outline,
                    "About",
                    "Learn more about this app",
                    null,
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: ListTile(
                    onTap: () => _showLogoutDialog(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.logout,
                        color: Colors.red.shade600,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      "Log Out",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _buildListTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppColors.secondary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey.shade400,
        size: 16,
      ),
    );
  }

  static Widget _buildSwitchTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool value,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: (_) {},
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppColors.secondary,
          size: 22,
        ),
      ),
      activeColor: AppColors.secondary,
      activeTrackColor: AppColors.secondary.withOpacity(0.3),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  static Widget _buildInfoTile(
    IconData icon,
    String title,
    String value,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: AppColors.secondary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  static Widget _buildSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
