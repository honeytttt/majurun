import 'package:flutter/material.dart';
import 'package:majurun/core/services/notification_service.dart';

/// Bell button to subscribe to a user's posts (like YouTube)
/// Shows on OTHER users' profiles only
class NotificationBellButton extends StatefulWidget {
  final String userId;
  final double size;

  const NotificationBellButton({
    super.key,
    required this.userId,
    this.size = 24,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _notificationService.subscriptionStream(widget.userId),
      builder: (context, snapshot) {
        final isSubscribed = snapshot.data ?? false;

        return IconButton(
          onPressed: _isLoading ? null : () => _toggleSubscription(isSubscribed),
          icon: _isLoading
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E676),
                  ),
                )
              : Icon(
                  isSubscribed
                      ? Icons.notifications_active
                      : Icons.notifications_none_outlined,
                  size: widget.size,
                  color: isSubscribed ? const Color(0xFF00E676) : Colors.grey[600],
                ),
          tooltip: isSubscribed ? 'Turn off notifications' : 'Get notified',
        );
      },
    );
  }

  Future<void> _toggleSubscription(bool currentlySubscribed) async {
    setState(() => _isLoading = true);

    try {
      if (currentlySubscribed) {
        await _notificationService.unsubscribeFromUser(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications turned off'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _notificationService.subscribeToUser(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You\'ll be notified when they post'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
