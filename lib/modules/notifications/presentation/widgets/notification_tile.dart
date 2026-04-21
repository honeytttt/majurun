import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:majurun/modules/notifications/domain/entities/app_notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: notification.read ? Colors.white : const Color(0xFFE8F5E9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessage(),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              _buildTypeIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (notification.type == NotificationType.badge) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.emoji_events,
          color: Color(0xFF00E676),
          size: 28,
        ),
      );
    }

    if (notification.type == NotificationType.reminder) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.directions_run_rounded,
          color: Colors.orange,
          size: 28,
        ),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[200],
      backgroundImage: notification.fromUserPhotoUrl != null &&
              notification.fromUserPhotoUrl!.isNotEmpty
          ? CachedNetworkImageProvider(notification.fromUserPhotoUrl!)
          : null,
      child: notification.fromUserPhotoUrl == null ||
              notification.fromUserPhotoUrl!.isEmpty
          ? Icon(Icons.person, color: Colors.grey[400])
          : null,
    );
  }

  Widget _buildMessage() {
    // System notifications (badge, reminder) show the full message directly
    // without a "from user" prefix.
    final isSystemNotif = notification.type == NotificationType.badge ||
        notification.type == NotificationType.reminder;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
        children: [
          if (!isSystemNotif)
            TextSpan(
              text: notification.fromUsername,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          TextSpan(
            text: isSystemNotif
                ? notification.message
                : ' ${_getActionText()}',
          ),
        ],
      ),
    );
  }

  String _getActionText() {
    switch (notification.type) {
      case NotificationType.follow:
        return 'started following you';
      case NotificationType.dm:
        return 'sent you a message';
      case NotificationType.like:
        return 'liked your post';
      case NotificationType.comment:
        return 'commented on your post';
      case NotificationType.post:
        return 'shared a new post';
      case NotificationType.badge:
      case NotificationType.reminder:
        return '';
    }
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.follow:
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case NotificationType.dm:
        icon = Icons.mail;
        color = Colors.purple;
        break;
      case NotificationType.badge:
        icon = Icons.emoji_events;
        color = const Color(0xFF00E676);
        break;
      case NotificationType.like:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.comment:
        icon = Icons.chat_bubble;
        color = Colors.orange;
        break;
      case NotificationType.post:
        icon = Icons.article;
        color = const Color(0xFF00E676);
        break;
      case NotificationType.reminder:
        icon = Icons.directions_run_rounded;
        color = Colors.orange;
        break;
    }

    return Icon(icon, size: 20, color: color.withValues(alpha: 0.7));
  }
}
