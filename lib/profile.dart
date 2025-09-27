import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 👉 import your real pages here
import 'package:capstone_project/Accounts/personal_info_page.dart';
import 'package:capstone_project/Accounts/change_password_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Signing out...'),
            ],
          ),
        ),
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to auth wrapper (which will show login page)
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Sign Out'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Account",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Benjamin Sepada III",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "benjaminlll.sepada@gmail.com",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Account Settings
          _buildSection([
            _buildListTile(
              Icons.person_outline,
              "Personal Info",
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
              ),
            ),
            _buildListTile(
              Icons.vpn_key_outlined,
              "Change Password",
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
            _buildListTile(Icons.lock_outline, "Two Factor Authentication"),
            _buildListTile(Icons.fingerprint, "Biometric Login"),
          ]),

          const SizedBox(height: 20),

          // Preferences
          _buildSection([
            _buildSwitchTile(Icons.dark_mode_outlined, "Dark Mode", false),
            _buildListTile(Icons.notifications_outlined, "Notifications"),
            _buildListTile(Icons.settings_outlined, "Settings"),
          ]),

          const SizedBox(height: 20),

          // Logout
          _buildSection([
            _buildListTile(Icons.logout, "Log Out", () => _showLogoutDialog(context)),
          ]),
        ],
      ),
    );
  }

  // Updated helper widget for list items with onTap
  static Widget _buildListTile(
      IconData icon,
      String title, [
        VoidCallback? onTap,
      ]) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFF7F9FC),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
    );
  }

  // Helper widget for switch item
  static Widget _buildSwitchTile(IconData icon, String title, bool value) {
    return SwitchListTile(
      value: value,
      onChanged: (_) {},
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      secondary: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFF7F9FC),
        child: Icon(icon, color: Colors.black87),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  // Section card wrapper
  static Widget _buildSection(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      color: const Color(0xFFF7F9FC),
      child: Column(children: children),
    );
  }
}
