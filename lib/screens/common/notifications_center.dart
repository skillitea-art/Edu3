import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NotificationsCenter extends StatelessWidget {
  const NotificationsCenter({super.key});

  List<AppNotification> _getMockNotifications() {
    return [
      AppNotification(
        id: '1',
        title: 'New Assignment Posted',
        body: 'Teacher added "Algebra Exercise 4" due in 2 days.',
        type: NotificationType.homework,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: '2',
        title: 'Live Announcement',
        body: 'Math Class timing shifted: Mon-Fri 5:00 PM - 7:00 PM starting tomorrow.',
        type: NotificationType.announcement,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: '3',
        title: 'Fire Streak! 🔥',
        body: 'Amazing! You kept your study streak alive for 3 days. Keep it up!',
        type: NotificationType.streak,
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      AppNotification(
        id: '4',
        title: 'Feedback Graded',
        body: 'Teacher reviewed your Physics performance and gave a 5-star rating.',
        type: NotificationType.feedback,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = _getMockNotifications();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notification Center'),
        centerTitle: true,
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(context, notification, isDark);
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No new alerts or reminders.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification, bool isDark) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.homework:
        icon = Icons.assignment_outlined;
        color = AppTheme.primaryColor;
        break;
      case NotificationType.announcement:
        icon = Icons.campaign_outlined;
        color = AppTheme.secondaryColor;
        break;
      case NotificationType.streak:
        icon = Icons.local_fire_department_rounded;
        color = Colors.orange;
        break;
      case NotificationType.feedback:
        icon = Icons.star_outline_rounded;
        color = Colors.purple;
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

enum NotificationType { homework, announcement, streak, feedback }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });
}
