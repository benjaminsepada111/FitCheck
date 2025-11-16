import 'package:flutter/material.dart';
import 'package:capstone_project/services/notification_storage_service.dart';
import 'package:capstone_project/color/colors.dart';

/// A notification bell icon with a badge showing unread count
/// Updates in real-time using Firestore streams
class NotificationBellIcon extends StatelessWidget {
  final VoidCallback onTap;
  final Color? iconColor;
  final double iconSize;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const NotificationBellIcon({
    super.key,
    required this.onTap,
    this.iconColor,
    this.iconSize = 24,
    this.badgeColor,
    this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationStorageService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Bell icon
                Icon(
                  Icons.notifications_outlined,
                  color: iconColor ?? Colors.black87,
                  size: iconSize,
                ),

                // Badge (only show if count > 0)
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(
                            color: badgeTextColor ?? Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A simpler notification icon button for AppBar
class NotificationIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? badgeColor;

  const NotificationIconButton({
    super.key,
    required this.onPressed,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationStorageService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: iconColor ?? Colors.black87,
              ),
              onPressed: onPressed,
              tooltip: 'Notifications',
            ),

            // Badge
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Notification badge for bottom navigation bar
class NotificationBottomNavIcon extends StatelessWidget {
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? badgeColor;

  const NotificationBottomNavIcon({
    super.key,
    required this.isActive,
    this.activeColor,
    this.inactiveColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationStorageService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isActive
                  ? Icons.notifications
                  : Icons.notifications_outlined,
              color: isActive
                  ? (activeColor ?? AppColors.secondary)
                  : (inactiveColor ?? Colors.grey),
            ),

            // Badge
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}