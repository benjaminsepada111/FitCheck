import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for storing and managing user notifications in Firestore
class NotificationStorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _notificationsCollection = 'notifications';

  /// Notification types
  static const String typeMealLogged = 'meal_logged';
  static const String typeMilestonePhoto = 'milestone_photo';
  static const String typeDailyGoal = 'daily_goal';
  static const String typeStreak = 'streak';
  static const String typeWorkoutLogged = 'workout_logged';
  static const String typeAchievementUnlocked = 'achievement_unlocked';
  static const String typeChallengeCompleted = 'challenge_completed';
  static const String typeGeneral = 'general';

  /// Save a notification to Firestore
  static Future<String?> saveNotification({
    required String type,
    required String title,
    required String description,
    String? iconName,
    int? iconColor,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot save notification: User not authenticated');
        return null;
      }

      final notificationData = {
        'type': type,
        'title': title,
        'description': description,
        'icon': iconName ?? _getDefaultIcon(type),
        'iconColor': iconColor ?? _getDefaultColor(type),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      };

      final docRef = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .add(notificationData);

      debugPrint('✅ Notification saved: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
      return null;
    }
  }

  /// Get all notifications for current user (ordered by date, newest first)
  static Stream<QuerySnapshot> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_notificationsCollection)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit to last 50 notifications
        .snapshots();
  }

  /// Get notifications as a future (for one-time fetch)
  static Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});

      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();

      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  static Future<void> deleteAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ All notifications deleted');
    } catch (e) {
      debugPrint('❌ Error deleting all notifications: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get unread notification count stream
  static Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .collection(_notificationsCollection)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Delete old notifications (older than specified days)
  static Future<void> deleteOldNotifications({int daysToKeep = 30}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .collection(_notificationsCollection)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Old notifications deleted (older than $daysToKeep days)');
    } catch (e) {
      debugPrint('❌ Error deleting old notifications: $e');
    }
  }

  /// Helper: Get default icon for notification type
  static String _getDefaultIcon(String type) {
    switch (type) {
      case typeMealLogged:
        return 'restaurant';
      case typeMilestonePhoto:
        return 'camera_alt';
      case typeDailyGoal:
        return 'fitness_center';
      case typeStreak:
        return 'local_fire_department';
      case typeWorkoutLogged:
        return 'fitness_center';
      case typeAchievementUnlocked:
        return 'emoji_events';
      case typeChallengeCompleted:
        return 'flag';
      default:
        return 'notifications';
    }
  }

  /// Helper: Get default color for notification type
  static int _getDefaultColor(String type) {
    switch (type) {
      case typeMealLogged:
        return 0xFFFF9800; // Orange
      case typeMilestonePhoto:
        return 0xFFE91E63; // Pink
      case typeDailyGoal:
        return 0xFF2196F3; // Blue
      case typeStreak:
        return 0xFFFF5722; // Red
      case typeWorkoutLogged:
        return 0xFF4CAF50; // Green
      case typeAchievementUnlocked:
        return 0xFFFFD700; // Gold
      case typeChallengeCompleted:
        return 0xFF9C27B0; // Purple
      default:
        return 0xFF757575; // Grey
    }
  }
}

/// Notification item model
class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String description;
  final String icon;
  final int iconColor;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    this.createdAt,
    this.metadata = const {},
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationItem(
      id: doc.id,
      type: data['type'] ?? NotificationStorageService.typeGeneral,
      title: data['title'] ?? 'Notification',
      description: data['description'] ?? '',
      icon: data['icon'] ?? 'notifications',
      iconColor: data['iconColor'] ?? 0xFF757575,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'icon': icon,
      'iconColor': iconColor,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'metadata': metadata,
    };
  }

  /// Get relative time string (e.g., "5 minutes ago")
  String getTimeAgo() {
    if (createdAt == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}